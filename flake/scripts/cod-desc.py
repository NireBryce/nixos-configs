#!/usr/bin/env python3
"""Semi-automate the ble.sh menu descriptions for cod completions
(cod-desc.tsv + cod-desc.bash, both next to blesh.nix).

cod serves its learned completions as bare words -- its sqlite Completion
table has Flag and Context columns and no description column, and its bash
protocol (COMPREPLY, one word per line) has no slot for one. ble.sh's menu
shows a description column anyway when candidates are re-yielded with one,
which is what cod-desc.bash does at completion time from the committed
cod-desc.tsv table. This script keeps that table cheap to grow: parsing
`--help` by hand for every flag of every command is the work nobody does,
and an out-of-date table reads exactly like a missing one.

    cod-desc.py draft sops [uv ...]   # draft TSV lines for commands, stdout
    cod-desc.py audit                 # cod's learned commands vs the table
    cod-desc.py check                 # validate the committed table's shape

`draft` runs `<command> --help` itself -- only point it at commands whose
--help is safe to execute. It prefers the candidate list cod actually serves
(queried live when the daemon has learned the command) over what a parse of
the help text finds, so drafts match the menu and not just the docs. Output
is a draft for curation: descriptions come from a line-oriented parse of the
help text (kingpin and clap shapes are pinned by test_cod_desc.py), they are
not authoritative. Review, edit, and only then add lines to cod-desc.tsv.

`audit` reports drift in both directions: commands cod has learned on this
host with no table rows (candidates that will show bare in the menu), and
table rows for commands cod has not learned (harmless -- the table can lead
-- but usually a sign the command was renamed). `--used` adds the gap
analysis against atuin history and carapace's spec list: the commands you
actually run that neither carapace nor the table covers, which is the queue
of things worth teaching cod next.

`check` enforces the table's mechanical invariants (three tab-separated
fields, sorted, unique, candidates never end in `=` -- the advice strips a
trailing `=` before lookup, so a row keyed with one could never match).
test_cod_desc.py runs the same check against the committed file, so
`just preflight` catches drift. See skill `cod-completions`
(.agents/skills/) for the whole workflow and the wiring in blesh.nix.
"""
import argparse
import os
import pathlib
import re
import sqlite3
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
FLAKE = HERE.parent
DATA = FLAKE / 'modules/config-system/shell-config/bash/cod-desc.tsv'

COD_DB = pathlib.Path('~/.local/share/cod/db.sqlite3').expanduser()

HELP_TIMEOUT = 15  # seconds; cod's own limit is 1s and misses slow --help


# ── the committed table ──────────────────────────────────────────────────────

def read_table(path=DATA):
    """Parse cod-desc.tsv into {(command, candidate): description}.

    Lines starting with '#' are comments; every other line must be exactly
    three tab-separated fields. Raises ValueError with a line number on
    anything else -- check() and the fixture test both rely on this being
    strict, since a malformed line would silently drop out of the advice's
    lookup instead of erroring.
    """
    rows = {}
    for lineno, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw
        if line.startswith('#'):
            continue
        if not line:
            continue
        fields = line.split('\t')
        if len(fields) != 3:
            raise ValueError(f'{path}:{lineno}: want 3 tab-separated fields, '
                             f'got {len(fields)}')
        command, candidate, desc = fields
        if not command or not candidate or not desc:
            raise ValueError(f'{path}:{lineno}: empty field')
        if candidate.endswith('='):
            raise ValueError(f'{path}:{lineno}: candidate {candidate!r} ends '
                             'in "=" -- the advice strips a trailing = before '
                             'lookup, so this row could never match')
        if (command, candidate) in rows:
            raise ValueError(f'{path}:{lineno}: duplicate key '
                             f'{command} {candidate}')
        rows[command, candidate] = desc
    return rows


def check_sorted(path=DATA):
    """Candidate rows must be sorted by (command, candidate) among
    themselves -- keeps the diff readable and makes duplicates obvious."""
    keys = [k for k in read_table(path)]
    if keys != sorted(keys):
        bad = [k for old, k in zip(keys, keys[1:]) if k <= old]
        raise ValueError(f'{path}: rows out of sorted order near {bad[0]}')


# ── cod's own state ──────────────────────────────────────────────────────────

def cod_learned():
    """Commands cod has learned on this host, as basenames.

    HelpPage.ExecutablePath is an absolute path; completions are registered
    under the basename, which is what COMP_WORDS[0] holds when the advice
    looks a candidate up. Read-only: the URI mode=ro means a corrupt or
    locked db fails here instead of being rewritten by accident.
    """
    if not COD_DB.exists():
        return []
    db = sqlite3.connect(f'file:{COD_DB}?mode=ro', uri=True)
    try:
        rows = db.execute('SELECT ExecutablePath FROM HelpPage').fetchall()
    finally:
        db.close()
    return sorted({pathlib.Path(p).name for (p,) in rows})


def cod_candidates(command):
    """The candidate list cod actually serves for a learned command, or None.

    Same call the completer itself makes (shells.go __cod_complete_bash):
    `cod api complete-words -- <pid> <cword> <words...>`. The pid is only an
    idempotency key for the daemon, so this shell's $$ is as good as any.
    """
    proc = subprocess.run(
        ['cod', 'api', 'complete-words', '--', str(os.getpid()),
         '2', command, ''],
        capture_output=True, text=True, timeout=10)
    if proc.returncode != 0:
        return None
    return proc.stdout.split()


# ── --help parsing (draft support) ───────────────────────────────────────────

# Section headers: plain ones (Commands:, COMMANDS:, flags:) and qualified
# ones ("Cache options:", "Global options:" -- uv splits its option blocks
# per topic). Anything ending in `:` that matches neither shape (usage
# prose, EXAMPLES:) just is not a section we parse.
SECTION_RE = re.compile(
    r'^\s*(?:(?:GLOBAL OPTIONS)|'
    r'(?:[A-Z][a-z]+ )?[Oo]ptions|'
    r'(?:COMMANDS|Commands|[Ss]ubcommands)|'
    r'(?:Flags|flags)):\s*$')
# One token of an option line's flag column: a dash-token (the only kind
# that becomes a candidate; clap's repeat marker `--quiet...` carries up to
# three dots that are not part of the candidate), a <BRACKETED> placeholder
# (clap: `--cache-dir <CACHE_DIR>`), or a bare placeholder word (kingpin:
# `--kms value, -k value`).
FLAG_TOKEN = r'(?:-{1,2}[\w][\w=-]*\.{0,3}|<[^>]+>|[A-Z_]{2,}|value)'
OPTION_RE = re.compile(
    r'^(\s+)(' + FLAG_TOKEN + r'(?:\s*,\s*|\s+' + FLAG_TOKEN + r')*)'
    r'\s{2,}(\S.*)$')
# clap's long-help style puts the description on the following line, more
# indented than the flag itself:
#     -q, --quiet...
#               Use quiet output
OPTION_BARE_RE = re.compile(
    r'^(\s+)(' + FLAG_TOKEN + r'(?:\s*,\s*|\s+' + FLAG_TOKEN + r')*)\s*$')
COMMAND_RE = re.compile(r'^\s+([\w][\w-]*)'
                        r'(?:,\s*[\w-]+)?'  # kingpin alias: "help, h"
                        r'\s{2,}(\S.*)$')

NOISE_RE = re.compile(
    r'\s+\[(?:env: [^\]]*|possible values: [^\]]*|default: [^\]]*)\]'
    r'|\s+\[\$[A-Z_]+\]'
    r'|\s+\(default:? [^)]*\)')


def clean_desc(text):
    """Menu-facing description: drop env/possible-value/default annotations,
    collapse the whitespace that wrapped continuation lines left behind."""
    text = NOISE_RE.sub('', text)
    return re.sub(r'\s+', ' ', text).strip()


def parse_help(text):
    """Extract {(candidate): description} from a --help text.

    Line-oriented and conservative; it is a drafting aid, not a spec. Two
    shapes are recognised and pinned by fixtures in test_cod_desc.py:

    kingpin (Go, sops/cod) -- sections in caps with the flag column holding
    inline placeholders, and a COMMANDS block:
        --kms value, -k value     comma separated list of KMS ARNs [$SOPS_KMS_ARN]
        completion  Generate shell completion scripts
    clap (Rust, uv) -- description possibly wrapped onto continuation lines
    indented to the description column, <BRACKETED> placeholders:
        -n, --no-cache            Avoid reading from or writing to the cache
        --cache-dir <CACHE_DIR>   Path to the cache directory
    Anything else (argconv, hand-rolled usage strings) yields what it
    yields -- `draft` prints what it found so gaps are visible.
    """
    found = {}
    section = None
    desc_col = None
    pending = None  # (indent, tokens) awaiting clap long-help descriptions
    if not text:
        return found
    for line in text.splitlines():
        if SECTION_RE.match(line):
            section = 'commands' if 'COMMAND' in line.upper() else 'options'
            desc_col = None
            pending = None
            continue
        if section is None:
            continue
        if not line.strip():
            section = None
            desc_col = None
            pending = None
            continue
        if section == 'options':
            m = OPTION_RE.match(line)
            b = None if m else OPTION_BARE_RE.match(line)
            if m:
                indent, column, desc = m.groups()
                desc_col = len(indent.expandtabs()) + \
                    len(column.expandtabs()) + 2
                pending = None
                for token in re.findall(r'-{1,2}[\w][\w=-]*', column):
                    candidate = token.rstrip('=')
                    if candidate not in found:
                        found[candidate] = clean_desc(desc)
            elif b:
                # clap long-help: flag column alone, description arrives on
                # the following line(s), more indented than the flag
                indent, column = b.groups()
                pending = (len(line) - len(line.lstrip()),
                           re.findall(r'-{1,2}[\w][\w=-]*', column))
                for token in pending[1]:
                    found.setdefault(token.rstrip('='), '')
                desc_col = None
            elif pending is not None:
                stripped = line.strip()
                if stripped and not stripped.startswith('-') and \
                        len(line) - len(line.lstrip()) > pending[0]:
                    text_piece = clean_desc(line)
                    for token in pending[1]:
                        candidate = token.rstrip('=')
                        found[candidate] = clean_desc(
                            found.get(candidate, '') + ' ' + text_piece)
                else:
                    pending = None
            elif desc_col is not None and \
                    len(line.expandtabs()) > desc_col and \
                    not line.lstrip().startswith('-'):
                # clap wraps long descriptions onto lines indented at least
                # to the description column; append to whichever candidate
                # was parsed last
                if found:
                    last = next(reversed(found))
                    found[last] = clean_desc(found[last] + ' ' + line)
        elif section == 'commands':
            m = COMMAND_RE.match(line)
            if m:
                name, desc = m.groups()
                if name not in found:
                    found[name] = clean_desc(desc)
    return {c: d for c, d in found.items() if d}


def run_help(command):
    """`<command> --help` output, or None. Only ever adds `--help` to the
    command the user named -- no shell, no other flags. Some tools (e.g.
    tailscale) print their help to stderr and exit non-zero; both streams
    are draft fodder, so either is returned."""
    try:
        proc = subprocess.run([command, '--help'], capture_output=True,
                              text=True, timeout=HELP_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as err:
        print(f'cod-desc: {command}: --help failed: {err}', file=sys.stderr)
        return None
    return proc.stdout or proc.stderr or None


# ── the subcommands ──────────────────────────────────────────────────────────

def cmd_draft(args):
    table = read_table()
    learned = set(cod_learned())
    for command in args.command:
        help_text = run_help(command)
        if help_text is None:
            continue
        parsed = parse_help(help_text)

        # Prefer the candidate list cod actually serves -- drafts then match
        # the menu rather than the docs, which differ (cod serves both the
        # long and short spellings of a flag, and subcommand names, but not
        # every alias the help text lists). Fall back to the parse for
        # commands cod has not learned.
        served = cod_candidates(command) if command in learned else None
        source = 'cod serves these'
        if served is None:
            served = sorted(parsed, key=lambda c: (not c.startswith('--'), c))
            source = 'parsed from --help'

        for candidate in served:
            if (command, candidate) in table:
                continue
            desc = parsed.get(candidate) or f'TODO ({source})'
            print(f'{command}\t{candidate}\t{desc}')
    return 0


def cmd_audit(args):
    table = read_table()
    table_commands = {c for c, _ in table}
    learned = cod_learned()

    untabled = [c for c in learned if c not in table_commands]
    if untabled:
        print('learned by cod, no rows in the table (candidates show bare):')
        for command in untabled:
            n = len(cod_candidates(command) or [])
            print(f'  {command} ({n} candidates)')
    unlearned = sorted(table_commands - set(learned))
    if unlearned:
        print('in the table, not learned on this host (rows dormant until'
              ' `cod learn -- <cmd> --help` runs):')
        for command in unlearned:
            print(f'  {command}')
    if not untabled and not unlearned:
        print('cod\'s learned commands and the table agree')

    if args.used:
        used = atuin_top_commands()
        covered = carapace_specs()
        queue = [c for c in used
                 if c not in covered and c not in table_commands]
        if queue:
            print('used recently, outside carapace and the table (worth'
                  ' `cod learn -- <cmd> --help`):')
            for command in queue:
                print(f'  {command}')
    return 0


def atuin_top_commands(limit=3000, top=40):
    """Most-used first words from atuin history.

    atuin refuses to run without ATUIN_SESSION in the environment (it is
    normally set per interactive shell); any value works for `search`.
    Best effort -- returns [] and says so rather than failing audit.
    """
    env = dict(os.environ, ATUIN_SESSION='cod-desc-audit')
    try:
        proc = subprocess.run(
            ['atuin', 'search', '--limit', str(limit),
             '--format', '{command}'],
            capture_output=True, text=True, timeout=30, env=env)
    except (OSError, subprocess.TimeoutExpired) as err:
        print(f'cod-desc: atuin unavailable: {err}', file=sys.stderr)
        return []
    counts = {}
    for line in proc.stdout.splitlines():
        word = line.split()
        if word:
            counts[word[0]] = counts.get(word[0], 0) + 1
    ranked = sorted(counts, key=lambda c: -counts[c])[:top]
    return [c for c in ranked if re.match(r'^[\w][\w.-]*$', c)]


def carapace_specs():
    """The command names carapace has a spec for (the ignore-list source).
    [] when carapace is absent -- e.g. off-host -- which makes the gap
    analysis report everything; fine for a draft queue."""
    try:
        proc = subprocess.run(['carapace', '--list'], capture_output=True,
                              text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return []
    try:
        import json
        return {str(k) for k in json.loads(proc.stdout)}
    except ValueError:
        return []


def cmd_check(_args):
    read_table()
    check_sorted()
    print(f'cod-desc: {DATA.relative_to(FLAKE.parent)} ok')
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        description='Semi-automate cod-desc.tsv: the ble.sh menu '
                    'descriptions for cod completions.')
    sub = parser.add_subparsers(dest='cmd', required=True)

    p_draft = sub.add_parser(
        'draft', help='draft TSV lines for commands, to stdout')
    p_draft.add_argument('command', nargs='+',
                         help='commands to draft rows for; their --help is '
                              'executed, so only name trusted commands')
    p_draft.set_defaults(func=cmd_draft)

    p_audit = sub.add_parser(
        'audit', help='cod\'s learned commands vs the committed table')
    p_audit.add_argument('--used', action='store_true',
                         help='also cross-check atuin history and carapace '
                              'coverage for the worth-learning queue')
    p_audit.set_defaults(func=cmd_audit)

    p_check = sub.add_parser(
        'check', help='validate the committed table\'s shape')
    p_check.set_defaults(func=cmd_check)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == '__main__':
    sys.exit(main())
