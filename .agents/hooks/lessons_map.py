"""Reads `.agents/lessons-map.toml`, the topic map: which paths and commands
a lesson, skill or rules file applies to (issue #460).

Three readers share this module, so they cannot disagree about what a topic
matches:

  lesson-reminder-pretooluse.py   the hook: one reminder per topic per
                                  session, before an edit or a command
  .agents/scripts/lessons.py      `just agent lessons [<path>...]`
  tools/docchecks/lessons.py           `lessons` check: validate() below

Globs use Claude Code's `paths:` semantics (`.agents/rules/*.md` frontmatter),
because a topic that names a rules file must list that file's globs exactly
and both must select the same files. Stdlib only; tomllib needs Python 3.11.
"""
import pathlib
import re
try:
    import tomllib
except ImportError:  # Python < 3.11 (e.g. a darwin system python3)
    tomllib = None

MAP = pathlib.Path('.agents') / 'lessons-map.toml'

KEYS = {'id', 'paths', 'command', 'unless', 'skill', 'rules', 'lessons',
        'see', 'remind', 'remind_on', 'delivered_by'}
REMIND_ON = ('edit', 'create', 'never')
ID = re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')


def glob_regex(pattern):
    """A Claude Code `paths:` glob as a regex over repo-relative paths:
    `**/` is zero or more directories, `**` anything, `*` and `?` stay
    within one path segment, `{a,b}` is alternation. Enough for the shapes
    rules here use; brackets are taken literally."""
    out, pos = [], 0
    while pos < len(pattern):
        char = pattern[pos]
        if pattern.startswith('**/', pos):
            out.append('(?:.*/)?')
            pos += 3
            continue
        if pattern.startswith('**', pos):
            out.append('.*')
            pos += 2
            continue
        if char == '*':
            out.append('[^/]*')
        elif char == '?':
            out.append('[^/]')
        elif char == '{':
            end = pattern.find('}', pos)
            if end < 0:
                out.append(re.escape(char))
            else:
                alts = pattern[pos + 1:end].split(',')
                out.append('(?:' + '|'.join(re.escape(alternative) for alternative in alts) + ')')
                pos = end + 1
                continue
        else:
            out.append(re.escape(char))
        pos += 1
    return re.compile(''.join(out) + r'\Z')


def find_root(start):
    """The nearest ancestor of `start` (a file or directory, which need not
    exist yet -- a Write creating a file) holding the map. Each worktree
    carries its own map, so an edit in a worktree is matched against that
    worktree's version."""
    start_path = pathlib.Path(start)
    for directory in (start_path, *start_path.parents):
        if (directory / MAP).is_file():
            return directory
    return None


def load(root):
    """Topics as dicts, with `_globs`/`_command`/`_unless` compiled. Raises
    on a map that doesn't parse; validate() is what reports a bad one."""
    if tomllib is None:
        raise RuntimeError('reading .agents/lessons-map.toml needs Python 3.11+ (tomllib)')
    data = tomllib.loads((pathlib.Path(root) / MAP).read_text())
    topics = []
    for topic in data.get('topic', []):
        topic = dict(topic)
        topic['_globs'] = [glob_regex(glob) for glob in topic.get('paths', [])]
        topic['_command'] = re.compile(topic['command']) if 'command' in topic else None
        topic['_unless'] = re.compile(topic['unless']) if 'unless' in topic else None
        topics.append(topic)
    return topics


def match_path(topics, rel):
    return [topic for topic in topics if any(rx.match(rel) for rx in topic['_globs'])]


def match_command(topics, command):
    return [topic for topic in topics
            if topic['_command'] and topic['_command'].search(command)
            and not (topic['_unless'] and topic['_unless'].search(command))]


def pointers(topic):
    """Where the full rule lives, as one line: skill, rules file, §s, see."""
    out = []
    if topic.get('skill'):
        out.append(f".agents/skills/{topic['skill']}/SKILL.md")
    if topic.get('rules'):
        out.append(f".agents/rules/{topic['rules']}")
    if topic.get('lessons'):
        out.append('wiki/agent-lessons-learned.md '
                   + ', '.join(f'§{lesson_number}' for lesson_number in topic['lessons']))
    if topic.get('see'):
        out.append(topic['see'])
    return '; '.join(out)


# -- validation (factcheck lessons; tools/docchecks/lessons.py) ---------

def split_finding(line):
    """(tag, path, message) of one validate() line, `TAG  path: message`.

    validate() returns strings because this module is stdlib-only and cannot
    import factcheck's Finding. The factcheck plugin converts each line with
    this at its boundary: factcheck's runner needs Finding objects. A line
    that does not have the shape is kept whole under the map's own path."""
    tag, sep, rest = line.partition('  ')
    path, colon, message = rest.partition(': ')
    if not (sep and colon):
        return 'LESSONS MAP', MAP.as_posix(), line
    return tag, path, message


def validate(root, tracked, lesson_numbers, rule_globs):
    """Findings for a map that has drifted from the repo. `tracked` is the
    repo-relative tracked file list, `lesson_numbers` the §s the index has,
    `rule_globs` {rules filename: [globs]} from their frontmatter."""
    root = pathlib.Path(root)
    where = MAP.as_posix()
    if not (root / MAP).is_file():
        return [f"MISSING LESSONS MAP  {where}: the topic map is gone"]
    if tomllib is None:
        return [f"LESSONS MAP  {where}: not validated -- needs Python 3.11+ "
                f"(tomllib); run the lint with a newer python3"]
    try:
        raw = tomllib.loads((root / MAP).read_text())
    except tomllib.TOMLDecodeError as error:
        return [f"LESSONS MAP SYNTAX  {where}: {error}"]
    findings = []
    extra = set(raw) - {'topic'}
    if extra:
        findings.append(f"LESSONS MAP  {where}: unknown top-level key(s) "
                        f"{sorted(extra)}; only [[topic]] tables")
    seen, covered_rules = set(), set()
    for topic in raw.get('topic', []):
        tid = topic.get('id', '?')
        def bad(msg):
            findings.append(f"LESSONS MAP  {where} [{tid}]: {msg}")
        if not ID.match(str(tid)):
            bad("`id` must be kebab-case")
        if tid in seen:
            bad("duplicate id")
        seen.add(tid)
        for key in sorted(set(topic) - KEYS):
            bad(f"unknown key `{key}`")
        if ('paths' in topic) == ('command' in topic):
            bad("needs exactly one of `paths` or `command`")
        for glob in topic.get('paths', []):
            if not any(glob_regex(glob).match(tracked_file) for tracked_file in tracked):
                bad(f"glob {glob!r} matches no tracked file -- renamed?")
        for key in ('command', 'unless'):
            if key in topic:
                try:
                    re.compile(topic[key])
                except re.error as error:
                    bad(f"`{key}` is not a valid regex: {error}")
        if 'unless' in topic and 'command' not in topic:
            bad("`unless` only applies to a `command` topic")
        if topic.get('skill') and not (root / '.agents' / 'skills' / topic['skill']
                                   / 'SKILL.md').is_file():
            bad(f"skill `{topic['skill']}` does not exist")
        if topic.get('rules'):
            covered_rules.add(topic['rules'])
            if topic['rules'] not in rule_globs:
                bad(f"rules file .agents/rules/{topic['rules']} does not exist")
            elif sorted(rule_globs[topic['rules']]) != sorted(topic.get('paths', [])):
                bad(f"`paths` differ from .agents/rules/{topic['rules']}'s "
                    f"frontmatter -- they must select the same files")
        for lesson_number in topic.get('lessons', []):
            if lesson_number not in lesson_numbers:
                bad(f"§{lesson_number} has no entry in wiki/agent-lessons-learned.md")
        if topic.get('see'):
            target = topic['see'].split('#', 1)[0]
            if not (root / target).exists():
                bad(f"`see` target {target} does not exist")
        if topic.get('delivered_by'):
            hook = root / '.agents' / 'hooks' / topic['delivered_by']
            if not hook.is_file():
                bad(f"delivered_by hook {topic['delivered_by']} does not exist")
        on = topic.get('remind_on', 'edit')
        if on not in REMIND_ON:
            bad(f"`remind_on` must be one of {REMIND_ON}")
        if 'command' in topic and 'remind_on' in topic:
            bad("`remind_on` only applies to a `paths` topic")
        if not topic.get('remind') and on != 'never' and not topic.get('delivered_by'):
            bad("no `remind` text, so it reminds of nothing -- add one, or "
                "set remind_on = \"never\" for a lookup-only topic")
        if not any(topic.get(key) for key in ('skill', 'rules', 'lessons', 'see')):
            bad("names no skill, rules file, lesson or `see` -- a reminder "
                "must say where the full rule lives")
    for rule in sorted(set(rule_globs) - covered_rules):
        findings.append(f"LESSONS MAP  {where}: .agents/rules/{rule} has no "
                        f"topic -- add one with the same `paths`")
    return findings
