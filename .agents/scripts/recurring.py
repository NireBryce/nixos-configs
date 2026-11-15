#!/usr/bin/env python3
"""Which command fragments have agents re-typed across sessions?

Answers skill agent-scripts' question "is this worth a script?" with
evidence instead of a guess: an agent has no memory between sessions, but
its harness keeps history. Only the Bash command field is read, never tool
output. Sources (HARNESSES), sessions filtered to this repo:

  claude     ~/.claude/projects/<this checkout>/*.jsonl
  opencode   ~/.local/share/opencode/opencode*.db   (sqlite, read-only)
  zcode      ~/.zcode/cli/db/db.sqlite               (an OpenCode fork:
             same schema, tool named `Bash` rather than `bash`)

Each prints its own session count in the report, so a reader broken by a
format change shows as 0 rather than silently shrinking the totals.

Across hosts: `export` writes this host's observations -- shapes and
hashed session ids only, never a command -- to <host>.<harness>.json in a
clone of the private forge repo elly/agent-command-log, merging into what
is already there (so history outlives the harness's own retention), then
commits and pushes. The report merges every exported file with local
data -- this host's own export included, since it keeps sessions the
harness has since pruned -- and marks a source not exported in STALE_DAYS
(skill ship runs `export` before each PR, so STALE means that host and
harness haven't shipped lately). Files of an older FORMAT are skipped. Git runs with
BatchMode ssh, so a missing key fails fast instead of prompting.

Agents rarely repeat a whole command line; they reassemble the same
pieces. Each command is parsed into pipelines (a producer, then the filters
it was piped through; `&&`, `;`, newlines and `$(...)` start a new one),
and the report has three sections, each answering a different question:

  SEQUENCES    runs of 2-4 producers executed one after another, in >=
               --min-sessions sessions: the script candidates. A run is
               dropped when a longer run containing it was seen in nearly
               as many sessions -- the longer one is the real pattern.
  BATCH READS  how many sessions read several things in one call, and how
               many print echo/printf headers between commands. One line,
               because as fragments this habit pairs with everything and
               buries the rest; chains made only of readers count here.
  PIPELINES    per producer, the filters agents attach (`| head`,
               `| grep -i`): mostly plain Unix, a script there would hide
               what the reader learns from the command.
  JUST         sessions per `just` recipe called (`just agent show`,
               `just preflight`): whether a helper is being used.

--json emits the same structure for other tools.

The shape is the privacy boundary
---------------------------------
Each segment is reduced to a shape before anything is printed, and the
shape must never carry a literal from the command. So it is built
conservatively, from an allowlist rather than by removing what looks
sensitive:

  - a real shell tokenizer (shlex, punctuation-aware, quotes kept), so a
    `|` inside a quoted grep pattern stays in the pattern and a quoted
    `"-x"` stays a value. The first version split on a regex and leaked
    pattern pieces as fake commands (`git.moose"`, `infra-notes"`), found
    2026-09-29 by previewing one session.
  - heredoc bodies are dropped through their terminator; commands with
    `case` are dropped whole (pattern words sit where commands do).
  - a segment keeps its command name only if it is a builtin or an
    executable on PATH (`is_command`) and contains no `/`; anything else is
    <cmd>. Segments opening with `for`/`select`/`function` are dropped:
    the next word is a name, and `host`/`id` are executables too.
  - wrappers (`timeout 20 git`, `env X=1 git`) are skipped only bare; any
    option of their own (`sudo -u X`) makes the segment <cmd>.
  - flags: a standalone 1-3 letter cluster (`-rn`) or find's long options
    survive; longer or value-glued short flags keep one letter (`-uadmin`
    -> `-u`); `--x=y` -> `--x=<arg>`; `-20` -> `-N`; after `--`, all <arg>.
    Unquoted `--long-flag` names survive verbatim: a real, exported
    literal class, acceptable because flag names are what a script needs.
  - subcommand words survive only from a closed list per tool
    (SUBCOMMANDS), so `git checkout experimental` is `git checkout <arg>`.
  - `just`'s words survive only in recipe position and only when they
    name a recipe this repo's justfiles define (`just_recipes()`, read
    from `just --summary` at the repo root, `agent::show` as `agent
    show`), so `just agent show <path>` counts as itself but `just
    deploy-foo` is `just <word>`. Recipe names are repo-defined text,
    already public; anything else after `just` stays a placeholder.

Removed text renders as its category, never its content, so a reader can
tell a flag from a value: <path>, <n> (numbers, `40,80p`), <str> (quoted),
<var> (`$X`), <url>, <word>; `-u<val>` is a value that was glued to its
flag; <heredoc>, <loop>, <func> mark dropped structure. Counting groups on
the untyped form (`untyped()`), so `sed -n <n> <path>` and `sed -n <n>
<str>` are one row, shown as the commoner rendering.

A command that fails to tokenize is dropped whole. test_recurring.py
checks every shape token against that closed vocabulary, over hostile
cases from the regex version and from a review of this one. Residual: an
unquoted word that happens to be a 1-3 letter flag cluster (`-foo`) or a
real command name in command position still reads as one.

`just` invocations (already scripts) and <cmd> segments are skipped in
SEQUENCES and PIPELINES; JUST counts each recipe's sessions instead, which
is how adoption of a `just agent` helper is measured.

    recurring.py [--min-sessions N] [--top N] [--max-len N] [--json] [--no-sync]
    recurring.py --session <id-prefix>     # audit: one session's shapes
    recurring.py export                    # this host -> the forge repo
    recurring.py setup                     # clone the forge repo (once per host)
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shlex
import shutil
import socket
import sqlite3
import subprocess
import sys
from collections import Counter, defaultdict
from functools import lru_cache
from pathlib import Path

PROJECTS   = Path.home() / '.claude' / 'projects'
REMOTE     = 'forgejo@ts-cube:elly/agent-command-log.git'
STATE      = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local' / 'state'))
LOG_DIR    = STATE / 'nixos-configs' / 'agent-command-log'
STALE_DAYS = 21
MAX_LEN    = 4                         # longest sequence recorded
# Bumped whenever shaping gets stricter: a file written under older rules
# may hold keys the current ones would have dropped, and merging would keep
# them forever. Files of another format are skipped when reading and
# rebuilt, not merged, on the host's next export.
FORMAT     = 3                          # 3: recipe names kept, `just` kind
GIT_ENV    = {**os.environ,
              'GIT_SSH_COMMAND': 'ssh -o BatchMode=yes -o ConnectTimeout=8'}

# Per tool, the subcommand words worth keeping, as a closed list: an open
# "any bareword" rule kept branch names and unit names. Two-level tools
# list their second words under the first.
GIT_SUBS = ('add', 'branch', 'checkout', 'cherry-pick', 'clone', 'commit',
            'diff', 'fetch', 'grep', 'log', 'ls-files', 'ls-remote', 'merge',
            'pull', 'push', 'rebase', 'reflog', 'remote', 'reset', 'restore',
            'rev-parse', 'rm', 'show', 'status', 'switch', 'tag')
SUBCOMMANDS = {
    'git': {**{sub: set() for sub in GIT_SUBS},
            'worktree': {'add', 'list', 'prune', 'remove'},
            'stash': {'list', 'pop', 'show'}},
    'gh':  {'pr': {'checks', 'create', 'diff', 'list', 'merge', 'view'},
            'issue': {'close', 'create', 'list', 'view'},
            'run': {'list', 'view', 'watch'},
            'api': set(), 'repo': {'view'}},
    'nix': {'build': set(), 'develop': set(), 'eval': set(), 'log': set(),
            'path-info': set(), 'run': set(), 'search': set(), 'shell': set(),
            'why-depends': set(),
            'flake': {'check', 'lock', 'metadata', 'show', 'update'},
            'store': {'ls', 'diff-closures'}},
    'systemctl':  {'cat', 'is-active', 'list-units', 'restart', 'show',
                   'status', 'start', 'stop'},
    'tailscale':  {'ip', 'ping', 'serve', 'status'},
    'sops':       {'decrypt', 'encrypt', 'updatekeys'},
    'nh':         {'darwin', 'home', 'os'},
}
# Git options that consume the next token before the subcommand.
GIT_ARG_OPTS = {'-C', '-c'}
# Commands that run another command. Bare, they are skipped to reach it;
# with any option of their own (`sudo -u X`, `env -C DIR`, `xargs -n1`) the
# segment is <cmd>, since an option's value would land in command
# position. timeout's duration is the one positional allowed.
WRAPPERS = {'timeout', 'time', 'env', 'xargs', 'sudo', 'nice', 'nohup',
            'command', 'exec', 'stdbuf'}
DURATION = re.compile(r'^\d+(?:\.\d+)?[smhd]?$')
# Leading keywords are dropped; a segment opening with a binder is dropped
# whole, since the word after it is a name (`for host in`), not a command.
KEYWORDS = {'if', 'then', 'else', 'elif', 'fi', 'while', 'until', 'do',
            'done', 'esac', '!', '{', '}'}
BINDERS  = {'for', 'select', 'function'}
PUNCT      = set(';&|()<>\n')
REDIRECT   = re.compile(r'^(?:[<>]+&?|&>+|>&|<&)$')
ENV_ASSIGN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')
NAME       = re.compile(r'^[A-Za-z_][\w.+-]*$')
HEREDOC    = re.compile(r"(?<!<)<<-?\s*\\?(['\"]?)([\w-]+)\1")  # <<EOF <<'EOF' <<\EOF
# Short flags survive only as a 1-3 letter cluster standing alone (`-rn`,
# `-sb`); anything longer or with a value glued on (`-uadmin`, `-A4`) is
# cut to its first letter. find's single-dash long options are listed.
SHORT_FLAG = re.compile(r'^-[A-Za-z]{1,3}$')
LONG_FLAG  = re.compile(r'^(--[A-Za-z][A-Za-z0-9-]*)(=.*)?$')
FIND_OPTS  = {'-maxdepth', '-mindepth', '-type', '-name', '-iname', '-path',
              '-newer', '-mtime', '-size', '-exec', '-print', '-print0',
              '-delete', '-empty', '-prune'}
REPO = Path(__file__).resolve().parents[2]


@lru_cache(maxsize=None)
def checkout_root():
    """The main checkout, whatever its directory is called and even when
    this runs from a linked worktree: git's common dir sits inside it."""
    completed = subprocess.run(['git', '-C', str(REPO), 'rev-parse',
                        '--path-format=absolute', '--git-common-dir'],
                       capture_output=True, text=True)
    return Path(completed.stdout.strip()).parent if completed.returncode == 0 else REPO


def project_dirs():
    """Claude Code's history directories for this repo. It names one after
    the session's working directory with every character outside
    [A-Za-z0-9-] turned into `-`, so `/home/u/nixos` is `-home-u-nixos`.
    The checkout's own directory and its `-<suffix>` siblings (worktrees
    made next to it) match, and so does any `*nixos-configs*`, the name
    other hosts clone it under. Matching only that name left a checkout
    named anything else at 0 sessions and never exported."""
    enc = re.sub(r'[^A-Za-z0-9-]', '-', str(checkout_root()))
    found = {*PROJECTS.glob('*nixos-configs*'), *PROJECTS.glob(enc),
             *PROJECTS.glob(enc + '-*')}
    return sorted(project_dir for project_dir in found if project_dir.is_dir())


# A longer fragment seen in at least this share of a shorter one's
# sessions absorbs it.
ABSORB = 0.8


@lru_cache(maxsize=None)
def is_command(name):
    """Shell builtin or an executable on this machine's PATH. Tests
    replace this, so the allowlist doesn't depend on the host."""
    return name in BUILTINS or shutil.which(name) is not None


@lru_cache(maxsize=None)
def just_recipes():
    """The recipe vocabulary for `just`, shaped like a SUBCOMMANDS entry:
    {recipe: set(), module: {recipe, ...}} from `just --summary` at the
    repo root (module recipes print as `agent::show`), kept only where the
    recipe is also defined in origin/experimental's justfiles -- so a name
    added on an unmerged branch or in an edited worktree never reaches an
    export. {} when just or git is missing or fails: every word after `just`
    is then a placeholder, the old behaviour. Tests replace this, like
    is_command."""
    try:
        completed = subprocess.run(['just', '--summary'], cwd=REPO, capture_output=True,
                           text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return {}
    if completed.returncode:
        return {}
    published = published_recipes()
    if published is None:
        return {}
    vocab = {}
    for name in completed.stdout.split():
        mod, _, recipe = name.rpartition('::')
        if not NAME.match(recipe) or (mod and not NAME.match(mod)):
            continue
        if recipe not in published.get(mod, set()):
            continue
        if mod:
            vocab.setdefault(mod, set()).add(recipe)
        else:
            vocab.setdefault(recipe, set())
    return vocab


# A recipe header: name, optional parameters (defaults may contain `=`),
# then a `:` that isn't `:=`; `name := value` is an assignment, not a recipe.
RECIPE_HEADER = re.compile(r'^@?([A-Za-z_][\w-]*)(?!\s*:=)\b[^\n:]*:(?!=)', re.M)
MOD_LINE = re.compile(r"^mod\s+([A-Za-z_][\w-]*)\s+['\"]([^'\"]+)['\"]", re.M)


def published_recipes():
    """{module: {recipe, ...}} ('' for the root justfile) as defined on
    origin/experimental, read with `git show` (text only, nothing run).
    None when git can't read it."""
    def show(path):
        completed = subprocess.run(['git', '-C', str(REPO), 'show',
                            f'origin/experimental:{path}'],
                           capture_output=True, text=True, timeout=10)
        return completed.stdout if completed.returncode == 0 else None
    try:
        top = show('.justfile')
        if top is None:
            return None
        out = {'': set(RECIPE_HEADER.findall(top))}
        for mod, path in MOD_LINE.findall(top):
            rel = path[2:] if path.startswith('./') else path
            text = None if rel.startswith('/') else show(rel)
            if text is not None:
                out[mod] = set(RECIPE_HEADER.findall(text))
        return out
    except (OSError, subprocess.SubprocessError):
        return None


BUILTINS = {'cd', 'echo', 'printf', 'test', '[', 'read', 'export', 'set',
            'unset', 'source', '.', 'eval', 'true', 'false', 'wait', 'trap',
            'local', 'shift', 'exit', 'return', 'type', 'hash', 'pwd'}


def warn(msg):
    print(f'warning: {msg}', file=sys.stderr)


def claude_rows():
    """(session, command) from Claude Code's JSONL transcripts."""
    seen = set()
    for path in sorted(transcript for project_dir in project_dirs() for transcript in project_dir.glob('*.jsonl')):
        for line in path.read_text(errors='replace').splitlines():
            if '"tool_use"' not in line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            msg = event.get('message') if isinstance(event, dict) else None
            content = msg.get('content') if isinstance(msg, dict) else None
            for block in content if isinstance(content, list) else []:
                if (isinstance(block, dict) and block.get('type') == 'tool_use'
                        and block.get('name') == 'Bash'
                        and block.get('id') not in seen):
                    seen.add(block.get('id'))
                    inp = block.get('input')
                    cmd = inp.get('command') if isinstance(inp, dict) else None
                    if isinstance(cmd, str) and cmd:
                        yield event.get('sessionId'), cmd


def sqlite_rows(path):
    """(session, command) from an OpenCode-schema database: Bash calls are
    `part` rows with type `tool`, tool `bash`/`Bash`, the command at
    state.input.command. Opened read-only; a harness writing to it
    concurrently is fine (WAL)."""
    try:
        db = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
        rows = db.execute(
            "select p.session_id, p.data from part p join session s"
            " on s.id = p.session_id where (s.directory like '%nixos-configs%'"
            "     or substr(s.directory, 1, length(?1)) = ?1)"
            # json_valid first: one malformed row must not fail the query
            " and case when json_valid(p.data)"
            "     then json_extract(p.data, '$.type') end = 'tool'"
            " order by p.rowid",       # insertion order: sequences need it
            (str(checkout_root()),)).fetchall()
    except sqlite3.Error as error:
        warn(f'{path}: {error}')
        return
    for session, data in rows:
        try:
            part = json.loads(data)
        except (TypeError, ValueError):
            continue
        if (not isinstance(part, dict) or part.get('type') != 'tool'
                or str(part.get('tool')).lower() != 'bash'):
            continue
        st = part.get('state')
        inp = st.get('input') if isinstance(st, dict) else None
        cmd = inp.get('command') if isinstance(inp, dict) else None
        if isinstance(cmd, str) and cmd:
            yield session, cmd


def opencode_rows():
    for path in sorted(Path.home().glob('.local/share/opencode/opencode*.db')):
        yield from sqlite_rows(path)


def zcode_rows():
    path = Path.home() / '.zcode' / 'cli' / 'db' / 'db.sqlite'
    if path.exists():
        yield from sqlite_rows(path)


HARNESSES = {'claude': claude_rows, 'opencode': opencode_rows, 'zcode': zcode_rows}


def commands():
    """(session, command) across every harness, for --session."""
    for rows in HARNESSES.values():
        yield from rows()


HEREDOC_MARK = '__HEREDOC__'   # where a body was cut; renders as <heredoc>


def arg_type(tok):
    """What kind of value was removed -- a category, never the value."""
    if quoted(tok):
        return '<str>'
    if tok == HEREDOC_MARK:
        return '<heredoc>'
    if tok == '-':
        return '-'                     # stdin, as in `python3 -`
    if tok.startswith('$'):
        return '<var>'
    if '://' in tok:
        return '<url>'
    if re.fullmatch(r'[\d,.:+-]*\d[\d,.:+-]*[pd]?', tok):
        return '<n>'                   # 20, 40,80p, 1.5
    if ('/' in tok or tok.startswith(('~', '.')) or '*' in tok
            or re.search(r'\.\w{1,6}$', tok)):
        return '<path>'
    return '<word>'


PLACEHOLDER = re.compile(r'<(?:path|n|str|var|url|word|val|heredoc)>')


def untyped(seg):
    """The shape with every typed placeholder back to <arg> and runs
    collapsed: what counting groups on, so types don't split counts."""
    return re.sub(r'<arg>(?: <arg>)+', '<arg>', PLACEHOLDER.sub('<arg>', seg))


def strip_heredocs(cmd):
    """Heredoc bodies are data: drop each from its opening line through
    its terminator, keep everything around it. `<<<` is a here-string,
    handled as a redirect."""
    out, tags = [], []
    for line in cmd.split('\n'):
        if tags:
            if line.strip() == tags[0]:
                tags.pop(0)
            continue
        tags += [match.group(2) for match in HEREDOC.finditer(line)]
        out.append(HEREDOC.sub(f' {HEREDOC_MARK} ', line))
    return '\n'.join(out)


def tokenize(cmd):
    """Shell tokens, quotes kept (so a quoted `"-x"` stays a value, not a
    flag), punctuation runs as their own tokens, newline included. None if
    the command doesn't parse. Commands containing `case` are dropped:
    their pattern words (`host)`) sit where commands do."""
    # Backticks are left alone: pre-splitting on them also split the ones
    # inside quoted strings (markdown in a `gh ... --body "..."`), and the
    # prose between them parsed as commands. Unquoted, a backtick stays
    # inside its token, which then can't pass as a command name.
    cmd = strip_heredocs(cmd).replace('\\\n', ' ')
    # Non-POSIX shlex keeps quotes but doesn't process escapes, so a `\"`
    # inside a double-quoted body ended the string early and the prose
    # after it parsed as commands. Escaped characters are content, and
    # content is discarded anyway: neutralize them.
    cmd = re.sub(r'\\.', '_', cmd)
    lex = shlex.shlex(cmd, posix=False, punctuation_chars=''.join(PUNCT))
    lex.whitespace = ' \t\r'
    lex.whitespace_split = True
    lex.commenters = ''
    try:
        tokens = list(lex)
    except ValueError:
        return None
    if 'case' in tokens or any(unbalanced(token) for token in tokens):
        return None
    # A `<<` left after strip_heredocs is a heredoc form HEREDOC doesn't
    # know (`<<$T`, `<<'A B'`), whose body would parse as commands -- or a
    # shift in `$(( ))`. Either way, dropping the command is the safe side.
    if any(is_punct(token) and '<<' in token.replace('<<<', '') for token in tokens):
        return None
    return tokens


def unbalanced(tok):
    """A token whose quotes don't pair up means shlex and the shell
    disagree about where strings end -- `"...$(awk -F'"' ...)..."` nests
    quotes shlex can't follow, leaving tokens like `$f"`. Guessing is how
    prose leaked, so the whole command is dropped instead."""
    outer = tok[:1] if tok[:1] in ('"', "'") else None
    if outer and (len(tok) < 2 or tok[-1] != outer):
        return True
    return any(tok.count(quote) % 2 for quote in ('"', "'") if quote != outer)


def is_punct(tok):
    return all(ch in PUNCT for ch in tok)


def quoted(tok):
    return tok[:1] in ('"', "'")


def flag_shape(tok):
    if re.fullmatch(r'-\d+', tok):
        return '-N'
    if SHORT_FLAG.match(tok) or tok in FIND_OPTS:
        return tok
    match = LONG_FLAG.match(tok)
    if match:
        return match.group(1) + ('=' + arg_type(match.group(2)[1:]) if match.group(2) else '')
    if re.match(r'^-[A-Za-z]', tok):
        return tok[:2] + '<val>'       # `-uadmin` -> `-u<val>`: value was glued on
    return '<word>'                    # `---`: not a flag


def segment_shape(tokens):
    toks = list(tokens)
    while toks and toks[0] in KEYWORDS:
        toks.pop(0)
    if toks and toks[0] in BINDERS:
        return '<func>' if toks[0] == 'function' else '<loop>'
    if not toks:
        return None
    while toks and ENV_ASSIGN.match(toks[0]):
        toks.pop(0)
    while toks and toks[0] in WRAPPERS:
        wrapper = toks.pop(0)
        while wrapper == 'env' and toks and ENV_ASSIGN.match(toks[0]):
            toks.pop(0)
        if wrapper == 'timeout' and toks and DURATION.match(toks[0]):
            toks.pop(0)
        if toks and toks[0].startswith('-'):
            return '<cmd>'
    if not toks or toks[0] == 'cd':
        return None
    name = toks[0]
    if quoted(name) or '/' in name or not NAME.match(name) or not is_command(name):
        return '<cmd>'
    subs = just_recipes() if name == 'just' else SUBCOMMANDS.get(name)
    out, args = [name], toks[1:]
    index, opts_done = 0, False
    while index < len(args):
        tok = args[index]
        if name == 'git' and len(out) == 1 and tok in GIT_ARG_OPTS:
            index += 2                     # `git -C <dir> log`: reach the subcommand
            continue
        if not opts_done and tok == '--':
            opts_done = True           # everything after `--` is an argument
            out.append('--')
        elif name == 'just' and len(out) == 1 and ENV_ASSIGN.match(tok):
            pass                       # `just host=x build`: an override, dropped like `X=1 cmd`
        elif not opts_done and isinstance(subs, (set, dict)) and tok in subs:
            out.append(tok)
            subs = subs[tok] if isinstance(subs, dict) else None
        elif not opts_done and tok.startswith('-') and len(tok) > 1:
            out.append(flag_shape(tok))
            subs = None
        else:
            typed = arg_type(tok)
            if typed != out[-1]:
                out.append(typed)      # runs of one type collapse
            subs = None
        index += 1
    return ' '.join(out)


def pipelines(cmd):
    """One command as a list of pipelines, each a list of segment shapes:
    the producer first, then the filters it was piped through. `|` joins
    segments within a pipeline; `&&`, `;`, newlines and `$(...)` start a
    new one. [] if the command doesn't parse."""
    tokens = tokenize(cmd)
    if tokens is None:
        return []
    out, pipe, cur, skip_next = [], [], [], False
    defined = set()                    # functions defined in this command
    for tok in tokens + ['\n']:
        if skip_next:
            skip_next = False
            continue
        if not is_punct(tok):
            cur.append(tok)
            continue
        if REDIRECT.match(tok):
            skip_next = True           # drop the operator and its target,
            if cur and cur[-1].isdigit():
                cur.pop()              # and the fd in `2>&1`
            continue
        if tok.startswith('(') and len(cur) == 1 and NAME.match(cur[0]):
            defined.add(cur[0])
            cur = ['function']         # `name() {`: a definition, not a call
        if cur and cur[0] in defined:
            cur = ['./fn']             # a call to it: its name is a literal -> <cmd>
        shape = segment_shape(cur) if cur else None
        if shape:
            pipe.append(shape)
        cur = []
        if tok.strip('()\n') not in ('|', '|&') and pipe:
            out.append(pipe)           # anything but a plain pipe ends it
            pipe = []
    return out


def shape(cmd):
    """Segment shapes for one command, flattened; [] if it doesn't parse."""
    return [seg for pipe in pipelines(cmd) for seg in pipe]


# Producers whose chains are reading, not doing: several in one call is
# the batch-read habit, reported as one line rather than as chains.
READERS = {'cat', 'sed', 'head', 'tail', 'ls', 'find', 'grep', 'wc', 'stat',
           'du', 'jq', 'diff', 'file', 'tree', 'rg', 'fd', 'bat', 'less'}


def cmd_name(seg):
    return seg.split()[0]


def is_header(pipe):
    """A lone echo/printf: the separator agents print between reads."""
    return len(pipe) == 1 and cmd_name(pipe[0]) in ('echo', 'printf')


def filter_name(seg):
    """`head -N` and `head` are the same filter; others keep one flag."""
    name = cmd_name(seg)
    return name if name in ('head', 'tail') else ' '.join(seg.split()[:2])


def absorb(counts, min_sessions, top):
    """Rank tuples by session count, dropping any a longer tuple containing
    it nearly matches."""
    kept = {fragment: count for fragment, count in counts.items() if count >= min_sessions}
    def absorbed(fragment):
        return any(len(longer) > len(fragment) and kept[longer] >= ABSORB * kept[fragment]
                   and any(longer[offset:offset + len(fragment)] == fragment for offset in range(len(longer) - len(fragment) + 1))
                   for longer in kept)
    return sorted((fragment for fragment in kept if not absorbed(fragment)),
                  key=lambda fragment: (-kept[fragment], -len(fragment)))[:top], kept


def host():
    return socket.gethostname().split('.')[0]


def session_key(harness, session):
    """Session ids leave the machine hashed: enough to count distinct
    sessions across hosts, nothing to look up."""
    return hashlib.sha256(f'{harness}:{session}'.encode()).hexdigest()[:12]


KINDS = ('chains', 'pipes', 'just')


def empty_obs():
    return {'sessions': {}, **{kind: defaultdict(set) for kind in KINDS}}


def collect(rows, harness):
    """Observations from (session, command) rows: per hashed session its
    command count and batch/header flags; per typed sequence and pipeline
    shape (tab-joined), the sessions it appeared in. This is all an export
    carries, and all ranking needs."""
    obs = empty_obs()
    for session, cmd in rows:
        session_id = session_key(harness, session)
        meta = obs['sessions'].setdefault(session_id, {'commands': 0, 'batch': False,
                                              'headers': False})
        meta['commands'] += 1
        ps = pipelines(cmd)
        if any(is_header(pipeline) for pipeline in ps) and len(ps) > 2:
            meta['headers'] = True
        producers = [pipeline[0] for pipeline in ps
                     if not is_header(pipeline) and cmd_name(pipeline[0]) not in ('just', '<cmd>')]
        if sum(cmd_name(command) in READERS for command in producers) >= 2:
            meta['batch'] = True
        for pipeline in ps:
            if cmd_name(pipeline[0]) == 'just':
                obs['just'][pipeline[0]].add(session_id)
            if len(pipeline) > 1 and cmd_name(pipeline[0]) not in ('just', '<cmd>'):
                obs['pipes']['\t'.join([pipeline[0], *map(filter_name, pipeline[1:])])].add(session_id)
        for length in range(2, MAX_LEN + 1):
            for start in range(len(producers) - length + 1):
                frag = producers[start:start + length]
                if not all(cmd_name(command) in READERS for command in frag):
                    obs['chains']['\t'.join(frag)].add(session_id)
    return obs


def merge(first, second):
    """Union of two observation sets; a session seen in both keeps the
    larger count and either's flags."""
    out = empty_obs()
    for src in (first, second):
        for session_id, meta in src['sessions'].items():
            cur = out['sessions'].setdefault(session_id, {'commands': 0, 'batch': False,
                                                 'headers': False})
            cur['commands'] = max(cur['commands'], meta['commands'])
            cur['batch'] |= meta['batch']
            cur['headers'] |= meta['headers']
        for kind in KINDS:
            for key, hs in src[kind].items():
                out[kind][key] |= set(hs)
    return out


def to_json(obs):
    return {'sessions': dict(sorted(obs['sessions'].items())),
            **{kind: {key: sorted(value) for key, value in sorted(obs[kind].items())}
               for kind in KINDS}}


def from_json(doc):
    """Observations from an export file; ValueError on anything that isn't
    the shape to_json writes, so one bad file is skipped, not fatal."""
    try:
        obs = empty_obs()
        for session_id, meta in doc['sessions'].items():
            obs['sessions'][str(session_id)] = {'commands': int(meta['commands']),
                                       'batch': bool(meta['batch']),
                                       'headers': bool(meta['headers'])}
        for kind in KINDS:
            for key, hs in doc[kind].items():
                if not isinstance(key, str) or not isinstance(hs, list):
                    raise TypeError(kind)
                obs[kind][key] = set(map(str, hs))
        return obs
    except (KeyError, TypeError, AttributeError, ValueError) as error:
        raise ValueError(f'not an export file ({error!r})') from None


def git(*args):
    """git in the log clone; never raises -- a timeout or missing git is a
    failed result, so the ship step reports it instead of tracebacking."""
    try:
        return subprocess.run(['git', '-C', str(LOG_DIR), *args], env=GIT_ENV,
                              capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as error:
        return subprocess.CompletedProcess(args, 1, '', str(error))


def pull():
    result = git('pull', '-q', '--rebase')
    if result.returncode:
        warn(f'could not pull the command log ({result.stderr.strip()[:120]}); '
             'using the local copy')


def load(path):
    """(document, obs) for a current-format export file; ValueError if it
    is malformed or another format."""
    try:
        doc = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise ValueError(f'unreadable ({error})') from None
    if not isinstance(doc, dict):
        raise ValueError('not an export file')
    if doc.get('format') != FORMAT:
        raise ValueError(f'format {doc.get("format")!r}, not {FORMAT}: rebuilt '
                         f'at that host\'s next export')
    return doc, from_json(doc)


def exported():
    """(label, obs, updated) for each usable file in the log clone -- this
    host's own included: it holds history the harness may have pruned."""
    for path in sorted(LOG_DIR.glob('*.json')) if LOG_DIR.exists() else []:
        try:
            doc, obs = load(path)
        except ValueError as error:
            warn(f'{path.name}: {error}; skipped')
            continue
        yield f'{doc.get("harness")}@{doc.get("host")}', obs, doc.get('updated')


def rank(obs, min_sessions, top, max_len):
    chains, pipes = defaultdict(set), defaultdict(set)
    variants = defaultdict(Counter)    # untyped key -> typed renderings
    for entry_key, hs in obs['chains'].items():
        frag = tuple(entry_key.split('\t'))
        if len(frag) <= max_len:
            key = tuple(untyped(word) for word in frag)
            chains[key] |= hs
            variants[key][frag] += len(hs)
    for entry_key, hs in obs['pipes'].items():
        prod, *filt = entry_key.split('\t')
        typed = (prod, tuple(filt))
        key = (untyped(prod), tuple(untyped(word) for word in filt))
        pipes[key] |= hs
        variants[key][typed] += len(hs)

    recipes = defaultdict(set)         # `just agent show` -> sessions
    for entry_key, hs in obs['just'].items():
        head = []
        for tok in entry_key.split()[1:]:
            if tok.startswith(('<', '-')):
                break
            head.append(tok)
        toks = entry_key.split()               # no recipe: `<word>`, `--summary`, bare
        recipes[' '.join(head) or (toks[1] if len(toks) > 1 else '(bare)')] |= hs

    seq, seq_n = absorb(
        {chain: len(session_set) for chain, session_set in chains.items()},
        min_sessions, top)
    by_producer = defaultdict(list)
    for key, session_set in pipes.items():
        if len(session_set) >= min_sessions:
            prod, filt = variants[key].most_common(1)[0][0]
            by_producer[untyped(prod)].append((len(session_set), prod, ' | '.join(filt)))
    producers = sorted(
        by_producer,
        key=lambda producer: -max(count for count, *_ in by_producer[producer]))[:top]
    meta = obs['sessions'].values()
    return {
        'sessions': len(obs['sessions']),
        'commands': sum(meta_entry['commands'] for meta_entry in meta),
        'header_sessions': sum(meta_entry['headers'] for meta_entry in meta),
        'batch_read_sessions': sum(meta_entry['batch'] for meta_entry in meta),
        'sequences': [{'sessions': seq_n[fragment],
                       'chain': list(variants[fragment].most_common(1)[0][0])}
                      for fragment in seq],
        'just': [{'sessions': len(hs), 'recipe': entry_key} for entry_key, hs in
                 sorted(recipes.items(), key=lambda kv: (-len(kv[1]), kv[0]))],
        'pipelines': [{'producer': max(by_producer[producer])[1], 'filters': [
            {'sessions': count, 'filters': fragment}
            for count, _, fragment in sorted(by_producer[producer], reverse=True)[:4]]}
            for producer in producers],
    }


def analyze(min_sessions, top, max_len, sync=True):
    """Local harnesses read live, plus every export (this host's too)."""
    if not just_recipes():
        warn('no recipe names from `just --summary`; every `just` call shapes'
             ' as `just <word>`')
    obs, sources = empty_obs(), []
    for harness, rows in HARNESSES.items():
        observations = collect(rows(), harness)
        sources.append({'source': f'{harness}@{host()}', 'local': True,
                        'sessions': len(observations['sessions'])})
        obs = merge(obs, observations)
    if (LOG_DIR / '.git').exists():
        if sync:
            pull()
        today = datetime.date.today()
        for label, observations, updated in exported():
            try:
                age = (today - datetime.date.fromisoformat(updated)).days
            except (TypeError, ValueError):
                age = None
            sources.append({'source': label, 'local': False,
                            'sessions': len(observations['sessions']), 'age_days': age,
                            'stale': age is None or age > STALE_DAYS})
            obs = merge(obs, observations)
    else:
        warn('command log not set up on this host (`just agent recurring setup`);'
             ' local sessions only')
    return {'sources': sources, **rank(obs, min_sessions, top, max_len)}


def report(analysis):
    pct = lambda count: f'{100 * count // max(analysis["sessions"], 1)}%'
    def src(entry):
        if entry['local']:
            return f'{entry["source"]} {entry["sessions"]}'
        age = '?' if entry['age_days'] is None else f'{entry["age_days"]}d'
        return f'{entry["source"]} {entry["sessions"]} ({age}{" STALE" if entry["stale"] else ""})'
    local = [src(entry) for entry in analysis['sources'] if entry['local']]
    other = [src(entry) for entry in analysis['sources'] if not entry['local']]
    print(f'{analysis["sessions"]} sessions, {analysis["commands"]} commands')
    print(f'  local:    {", ".join(local)}')
    print(f'  exported: {", ".join(other) or "(none)"}\n')
    print('SEQUENCES  commands run one after another -- script candidates')
    for sequence in analysis['sequences'] or [{'sessions': 0, 'chain': ['(none)']}]:
        print(f'  {sequence["sessions"]:3d}  ' + '  ->  '.join(sequence['chain'])[:150])
    print(f'\nBATCH READS  several reads in one call (cat/sed/ls/grep...): '
          f'{analysis["batch_read_sessions"]} sessions ({pct(analysis["batch_read_sessions"])}); '
          f'with echo/printf headers between: {analysis["header_sessions"]} '
          f'({pct(analysis["header_sessions"])})')
    print('\nPIPELINES  filters attached per producer -- mostly plain Unix')
    for pipeline in analysis['pipelines']:
        fs = ', '.join(f'| {filter_entry["filters"]} ({filter_entry["sessions"]})' for filter_entry in pipeline['filters'])
        print(f'  {pipeline["producer"][:40]:40s} {fs}'[:160])
    print('\nJUST  sessions calling each recipe -- helper adoption'
          ' (<word>: not a recipe here)')
    rows = [f'{just_entry["sessions"]:4d} {just_entry["recipe"]}' for just_entry in analysis['just']]
    for start in range(0, len(rows), 4):
        print('  ' + ''.join(f'{entry:30s}' for entry in rows[start:start + 4]).rstrip())
    if not rows:
        print('  (none)')


def show_session(prefix):
    """Audit view: what one session's commands reduce to. Prefix match on
    the session id, so the first 8 characters are enough."""
    rows = [' | '.join(shape(command)) or '(dropped)' for session_id, command in commands()
            if session_id and session_id.startswith(prefix)]
    print(f'{len(rows)} commands in session {prefix}')
    for row in rows:
        print('  ' + row[:150])


def setup():
    if (LOG_DIR / '.git').exists():
        print(f'already set up: {LOG_DIR}')
        return 0
    LOG_DIR.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(['git', 'clone', '-q', REMOTE, str(LOG_DIR)], env=GIT_ENV,
                       capture_output=True, text=True, timeout=60)
    if result.returncode:
        print(f'clone failed: {result.stderr.strip()} -- does this host have a forge '
              f'key? (wiki/homelab/forgejo-for-agents.md)', file=sys.stderr)
        return 1
    print(f'cloned {REMOTE} to {LOG_DIR}')
    return 0


def export():
    """Merge this host's observations into its files in the log repo,
    commit, push. One line of output: skill ship runs it every PR. Exit 1
    on a failure, which the ship step reports but doesn't stop for."""
    if not (LOG_DIR / '.git').exists():
        print('export skipped: command log not set up on this host '
              '(`just agent recurring setup`)')
        return 0
    pull()
    written, files = [], []
    for harness, rows in HARNESSES.items():
        obs = collect(rows(), harness)
        path = LOG_DIR / f'{host()}.{harness}.json'
        if path.exists():
            try:
                obs = merge(load(path)[1], obs)
            except ValueError as error:
                warn(f'{path.name}: {error}; rebuilding from live data')
        elif not obs['sessions']:
            continue                   # nothing here, nothing before
        # Rewritten even with no new sessions, so `updated` means "this
        # source was exported", and STALE means it wasn't.
        path.write_text(json.dumps({'format': FORMAT, 'host': host(),
                                    'harness': harness,
                                    'updated': datetime.date.today().isoformat(),
                                    **to_json(obs)}, indent=1) + '\n')
        written.append(f'{harness} {len(obs["sessions"])}')
        files.append(path.name)
    if not files:
        print(f'export: no sessions on {host()}')
        return 0
    git('add', '--', *files)
    if git('diff', '--cached', '--quiet', '--', *files).returncode:
        result = git('commit', '-qm', f'{host()}: export {datetime.date.today()}', '--', *files)
        if result.returncode:
            print(f'export failed: commit: {result.stderr.strip()[:200]}')
            return 1
    result = git('push', '-q')
    status = '' if result.returncode == 0 else \
        f' (committed locally; push failed, next export retries: {result.stderr.strip()[:120]})'
    print(f'exported {", ".join(written)} sessions from {host()}{status}')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('action', nargs='?', choices=['export', 'setup'])
    ap.add_argument('--min-sessions', type=int, default=3)
    ap.add_argument('--top', type=int, default=15)
    ap.add_argument('--max-len', type=int, default=MAX_LEN)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--no-sync', action='store_true',
                    help="don't pull the command log first")
    ap.add_argument('--session', metavar='ID',
                    help='one session: each command as its shape, in order')
    args = ap.parse_args()
    if args.action == 'setup':
        return setup()
    if args.action == 'export':
        return export()
    if args.session:
        return show_session(args.session)
    analysis = analyze(args.min_sessions, args.top, min(args.max_len, MAX_LEN),
                sync=not args.no_sync)
    if args.json:
        print(json.dumps(analysis, indent=1))
    else:
        report(analysis)


if __name__ == '__main__':
    sys.exit(main())
