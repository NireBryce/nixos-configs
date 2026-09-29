#!/usr/bin/env python3
"""Which command fragments have agents re-typed across sessions?

Answers skill agent-scripts' question "is this worth a script?" with
evidence instead of a guess: an agent has no memory between sessions, but
this machine's Claude transcripts for the repo (~/.claude/projects/
*nixos-configs*/) do. Only the Bash command field is read, never tool
output.

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
  - subcommand words survive only from a closed list per tool
    (SUBCOMMANDS), so `git checkout experimental` is `git checkout <arg>`.

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

`just` invocations (already scripts) and <cmd> segments are skipped.

    recurring.py [--min-sessions N] [--top N] [--max-len N] [--json]
    recurring.py --session <id-prefix>     # audit: one session's shapes
"""
import argparse
import json
import os
import re
import shlex
import shutil
from collections import Counter, defaultdict
from functools import lru_cache
from pathlib import Path

PROJECTS = Path.home() / '.claude' / 'projects'

# Per tool, the subcommand words worth keeping, as a closed list: an open
# "any bareword" rule kept branch names and unit names. Two-level tools
# list their second words under the first.
GIT_SUBS = ('add', 'branch', 'checkout', 'cherry-pick', 'clone', 'commit',
            'diff', 'fetch', 'grep', 'log', 'ls-files', 'ls-remote', 'merge',
            'pull', 'push', 'rebase', 'reflog', 'remote', 'reset', 'restore',
            'rev-parse', 'rm', 'show', 'status', 'switch', 'tag')
SUBCOMMANDS = {
    'git': {**{c: set() for c in GIT_SUBS},
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
HEREDOC    = re.compile(r"(?<!<)<<-?\s*(['\"]?)([\w-]+)\1")
# Short flags survive only as a 1-3 letter cluster standing alone (`-rn`,
# `-sb`); anything longer or with a value glued on (`-uadmin`, `-A4`) is
# cut to its first letter. find's single-dash long options are listed.
SHORT_FLAG = re.compile(r'^-[A-Za-z]{1,3}$')
LONG_FLAG  = re.compile(r'^(--[A-Za-z][A-Za-z0-9-]*)(=.*)?$')
FIND_OPTS  = {'-maxdepth', '-mindepth', '-type', '-name', '-iname', '-path',
              '-newer', '-mtime', '-size', '-exec', '-print', '-print0',
              '-delete', '-empty', '-prune'}
# A longer fragment seen in at least this share of a shorter one's
# sessions absorbs it.
ABSORB = 0.8


@lru_cache(maxsize=None)
def is_command(name):
    """Shell builtin or an executable on this machine's PATH. Tests
    replace this, so the allowlist doesn't depend on the host."""
    return name in BUILTINS or shutil.which(name) is not None


BUILTINS = {'cd', 'echo', 'printf', 'test', '[', 'read', 'export', 'set',
            'unset', 'source', '.', 'eval', 'true', 'false', 'wait', 'trap',
            'local', 'shift', 'exit', 'return', 'type', 'hash', 'pwd'}


def commands():
    """(session, command) for every Bash tool call in the transcripts."""
    seen = set()
    for path in sorted(PROJECTS.glob('*nixos-configs*/*.jsonl')):
        for line in path.read_text(errors='replace').splitlines():
            if '"tool_use"' not in line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            msg = e.get('message') if isinstance(e, dict) else None
            content = msg.get('content') if isinstance(msg, dict) else None
            for block in content if isinstance(content, list) else []:
                if (isinstance(block, dict) and block.get('type') == 'tool_use'
                        and block.get('name') == 'Bash'
                        and block.get('id') not in seen):
                    seen.add(block.get('id'))
                    inp = block.get('input')
                    cmd = inp.get('command') if isinstance(inp, dict) else None
                    if isinstance(cmd, str) and cmd:
                        yield e.get('sessionId'), cmd


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
        tags += [m.group(2) for m in HEREDOC.finditer(line)]
        out.append(HEREDOC.sub(f' {HEREDOC_MARK} ', line))
    return '\n'.join(out)


def tokenize(cmd):
    """Shell tokens, quotes kept (so a quoted `"-x"` stays a value, not a
    flag), punctuation runs as their own tokens, newline included. None if
    the command doesn't parse. Commands containing `case` are dropped:
    their pattern words (`host)`) sit where commands do."""
    cmd = strip_heredocs(cmd).replace('\\\n', ' ').replace('`', ' ; ')
    lex = shlex.shlex(cmd, posix=False, punctuation_chars=''.join(PUNCT))
    lex.whitespace = ' \t\r'
    lex.whitespace_split = True
    lex.commenters = ''
    try:
        tokens = list(lex)
    except ValueError:
        return None
    return None if 'case' in tokens else tokens


def is_punct(tok):
    return all(ch in PUNCT for ch in tok)


def quoted(tok):
    return tok[:1] in ('"', "'")


def flag_shape(tok):
    if re.fullmatch(r'-\d+', tok):
        return '-N'
    if SHORT_FLAG.match(tok) or tok in FIND_OPTS:
        return tok
    m = LONG_FLAG.match(tok)
    if m:
        return m.group(1) + ('=' + arg_type(m.group(2)[1:]) if m.group(2) else '')
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
    out, subs, args = [name], SUBCOMMANDS.get(name), toks[1:]
    i, opts_done = 0, False
    while i < len(args):
        tok = args[i]
        if name == 'git' and len(out) == 1 and tok in GIT_ARG_OPTS:
            i += 2                     # `git -C <dir> log`: reach the subcommand
            continue
        if not opts_done and tok == '--':
            opts_done = True           # everything after `--` is an argument
            out.append('--')
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
        i += 1
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
            cur = ['function']         # `name() {`: a definition, not a call
        s = segment_shape(cur) if cur else None
        if s:
            pipe.append(s)
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
    kept = {f: n for f, n in counts.items() if n >= min_sessions}
    def absorbed(f):
        return any(len(g) > len(f) and kept[g] >= ABSORB * kept[f]
                   and any(g[i:i + len(f)] == f for i in range(len(g) - len(f) + 1))
                   for g in kept)
    return sorted((f for f in kept if not absorbed(f)),
                  key=lambda f: (-kept[f], -len(f)))[:top], kept


def analyze(min_sessions, top, max_len):
    chains, pipes = defaultdict(set), defaultdict(set)
    variants = defaultdict(Counter)    # untyped key -> typed renderings
    batch, headers, total, ncmds = set(), set(), set(), 0
    for session, cmd in commands():
        total.add(session)
        ncmds += 1
        ps = pipelines(cmd)
        if any(is_header(p) for p in ps) and len(ps) > 2:
            headers.add(session)
        producers = [p[0] for p in ps
                     if not is_header(p) and cmd_name(p[0]) not in ('just', '<cmd>')]
        if sum(cmd_name(x) in READERS for x in producers) >= 2:
            batch.add(session)
        for p in ps:
            if len(p) > 1 and cmd_name(p[0]) not in ('just', '<cmd>'):
                typed = (p[0], tuple(filter_name(f) for f in p[1:]))
                key = (untyped(p[0]), tuple(untyped(f) for f in typed[1]))
                pipes[key].add(session)
                variants[key][typed] += 1
        for n in range(2, max_len + 1):
            for i in range(len(producers) - n + 1):
                frag = tuple(producers[i:i + n])
                if all(cmd_name(x) in READERS for x in frag):
                    continue           # batch reads: counted above
                key = tuple(untyped(x) for x in frag)
                chains[key].add(session)
                variants[key][frag] += 1

    seq, seq_n = absorb({f: len(s) for f, s in chains.items()}, min_sessions, top)
    by_producer = defaultdict(list)
    for key, s in pipes.items():
        if len(s) >= min_sessions:
            prod, filt = variants[key].most_common(1)[0][0]
            by_producer[untyped(prod)].append((len(s), prod, ' | '.join(filt)))
    producers = sorted(by_producer, key=lambda p: -max(n for n, *_ in by_producer[p]))[:top]
    return {
        'sessions': len(total), 'commands': ncmds,
        'header_sessions': len(headers), 'batch_read_sessions': len(batch),
        'sequences': [{'sessions': seq_n[f],
                       'chain': list(variants[f].most_common(1)[0][0])}
                      for f in seq],
        'pipelines': [{'producer': max(by_producer[p])[1], 'filters': [
            {'sessions': n, 'filters': f}
            for n, _, f in sorted(by_producer[p], reverse=True)[:4]]}
            for p in producers],
    }


def report(a):
    pct = lambda n: f'{100 * n // max(a["sessions"], 1)}%'
    print(f'{a["sessions"]} sessions, {a["commands"]} commands\n')
    print('SEQUENCES  commands run one after another -- script candidates')
    for s in a['sequences'] or [{'sessions': 0, 'chain': ['(none)']}]:
        print(f'  {s["sessions"]:3d}  ' + '  ->  '.join(s['chain'])[:150])
    print(f'\nBATCH READS  several reads in one call (cat/sed/ls/grep...): '
          f'{a["batch_read_sessions"]} sessions ({pct(a["batch_read_sessions"])}); '
          f'with echo/printf headers between: {a["header_sessions"]} '
          f'({pct(a["header_sessions"])})')
    print('\nPIPELINES  filters attached per producer -- mostly plain Unix')
    for p in a['pipelines']:
        fs = ', '.join(f'| {f["filters"]} ({f["sessions"]})' for f in p['filters'])
        print(f'  {p["producer"][:40]:40s} {fs}'[:160])


def show_session(prefix):
    """Audit view: what one session's commands reduce to. Prefix match on
    the session id, so the first 8 characters are enough."""
    rows = [' | '.join(shape(c)) or '(dropped)' for s, c in commands()
            if s and s.startswith(prefix)]
    print(f'{len(rows)} commands in session {prefix}')
    for row in rows:
        print('  ' + row[:150])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--min-sessions', type=int, default=3)
    ap.add_argument('--top', type=int, default=15)
    ap.add_argument('--max-len', type=int, default=4)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--session', metavar='ID',
                    help='one session: each command as its shape, in order')
    args = ap.parse_args()
    if args.session:
        return show_session(args.session)
    a = analyze(args.min_sessions, args.top, args.max_len)
    if args.json:
        print(json.dumps(a, indent=1))
    else:
        report(a)


if __name__ == '__main__':
    main()
