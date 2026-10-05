"""Reads `.agents/lessons-map.toml`, the topic map: which paths and commands
a lesson, skill or rules file applies to (issue #460).

Three readers share this module, so they cannot disagree about what a topic
matches:

  lesson-reminder-pretooluse.py   the hook: one reminder per topic per
                                  session, before an edit or a command
  .agents/scripts/lessons.py      `just agent lessons [<path>...]`
  wiki/scripts/check_wiki.py      `lessons` check: validate() below

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
    out, i = [], 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith('**/', i):
            out.append('(?:.*/)?'); i += 3; continue
        if pattern.startswith('**', i):
            out.append('.*'); i += 2; continue
        if c == '*':
            out.append('[^/]*')
        elif c == '?':
            out.append('[^/]')
        elif c == '{':
            end = pattern.find('}', i)
            if end < 0:
                out.append(re.escape(c))
            else:
                alts = pattern[i + 1:end].split(',')
                out.append('(?:' + '|'.join(re.escape(a) for a in alts) + ')')
                i = end + 1
                continue
        else:
            out.append(re.escape(c))
        i += 1
    return re.compile(''.join(out) + r'\Z')


def find_root(start):
    """The nearest ancestor of `start` (a file or directory, which need not
    exist yet -- a Write creating a file) holding the map. Each worktree
    carries its own map, so an edit in a worktree is matched against that
    worktree's version."""
    p = pathlib.Path(start)
    for d in (p, *p.parents):
        if (d / MAP).is_file():
            return d
    return None


def load(root):
    """Topics as dicts, with `_globs`/`_command`/`_unless` compiled. Raises
    on a map that doesn't parse; validate() is what reports a bad one."""
    if tomllib is None:
        raise RuntimeError('reading .agents/lessons-map.toml needs Python 3.11+ (tomllib)')
    data = tomllib.loads((pathlib.Path(root) / MAP).read_text())
    topics = []
    for t in data.get('topic', []):
        t = dict(t)
        t['_globs'] = [glob_regex(g) for g in t.get('paths', [])]
        t['_command'] = re.compile(t['command']) if 'command' in t else None
        t['_unless'] = re.compile(t['unless']) if 'unless' in t else None
        topics.append(t)
    return topics


def match_path(topics, rel):
    return [t for t in topics if any(rx.match(rel) for rx in t['_globs'])]


def match_command(topics, command):
    return [t for t in topics
            if t['_command'] and t['_command'].search(command)
            and not (t['_unless'] and t['_unless'].search(command))]


def pointers(t):
    """Where the full rule lives, as one line: skill, rules file, §s, see."""
    out = []
    if t.get('skill'):
        out.append(f".agents/skills/{t['skill']}/SKILL.md")
    if t.get('rules'):
        out.append(f".agents/rules/{t['rules']}")
    if t.get('lessons'):
        out.append('wiki/lessons-learned.md '
                   + ', '.join(f'§{n}' for n in t['lessons']))
    if t.get('see'):
        out.append(t['see'])
    return '; '.join(out)


# -- validation (check_wiki.py lessons) -------------------------------------

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
    except tomllib.TOMLDecodeError as e:
        return [f"LESSONS MAP SYNTAX  {where}: {e}"]
    findings = []
    extra = set(raw) - {'topic'}
    if extra:
        findings.append(f"LESSONS MAP  {where}: unknown top-level key(s) "
                        f"{sorted(extra)}; only [[topic]] tables")
    seen, covered_rules = set(), set()
    for t in raw.get('topic', []):
        tid = t.get('id', '?')
        def bad(msg):
            findings.append(f"LESSONS MAP  {where} [{tid}]: {msg}")
        if not ID.match(str(tid)):
            bad("`id` must be kebab-case")
        if tid in seen:
            bad("duplicate id")
        seen.add(tid)
        for k in sorted(set(t) - KEYS):
            bad(f"unknown key `{k}`")
        if ('paths' in t) == ('command' in t):
            bad("needs exactly one of `paths` or `command`")
        for g in t.get('paths', []):
            if not any(glob_regex(g).match(f) for f in tracked):
                bad(f"glob {g!r} matches no tracked file -- renamed?")
        for k in ('command', 'unless'):
            if k in t:
                try:
                    re.compile(t[k])
                except re.error as e:
                    bad(f"`{k}` is not a valid regex: {e}")
        if 'unless' in t and 'command' not in t:
            bad("`unless` only applies to a `command` topic")
        if t.get('skill') and not (root / '.agents' / 'skills' / t['skill']
                                   / 'SKILL.md').is_file():
            bad(f"skill `{t['skill']}` does not exist")
        if t.get('rules'):
            covered_rules.add(t['rules'])
            if t['rules'] not in rule_globs:
                bad(f"rules file .agents/rules/{t['rules']} does not exist")
            elif sorted(rule_globs[t['rules']]) != sorted(t.get('paths', [])):
                bad(f"`paths` differ from .agents/rules/{t['rules']}'s "
                    f"frontmatter -- they must select the same files")
        for n in t.get('lessons', []):
            if n not in lesson_numbers:
                bad(f"§{n} has no entry in wiki/lessons-learned.md")
        if t.get('see'):
            target = t['see'].split('#', 1)[0]
            if not (root / target).exists():
                bad(f"`see` target {target} does not exist")
        if t.get('delivered_by'):
            hook = root / '.agents' / 'hooks' / t['delivered_by']
            if not hook.is_file():
                bad(f"delivered_by hook {t['delivered_by']} does not exist")
        on = t.get('remind_on', 'edit')
        if on not in REMIND_ON:
            bad(f"`remind_on` must be one of {REMIND_ON}")
        if 'command' in t and 'remind_on' in t:
            bad("`remind_on` only applies to a `paths` topic")
        if not t.get('remind') and on != 'never' and not t.get('delivered_by'):
            bad("no `remind` text, so it reminds of nothing -- add one, or "
                "set remind_on = \"never\" for a lookup-only topic")
        if not any(t.get(k) for k in ('skill', 'rules', 'lessons', 'see')):
            bad("names no skill, rules file, lesson or `see` -- a reminder "
                "must say where the full rule lives")
    for r in sorted(set(rule_globs) - covered_rules):
        findings.append(f"LESSONS MAP  {where}: .agents/rules/{r} has no "
                        f"topic -- add one with the same `paths`")
    return findings
