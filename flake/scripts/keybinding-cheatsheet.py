#!/usr/bin/env python3
"""Render a normalized keybinding cheat sheet for one tool, with this repo's
overrides applied on top of whatever upstream defaults you feed it.

Exists because key notation differs per tool and hand-kept sheets rot:
kitty_mod+s, C-r, ^[[1;5C and \\e[1;5C are the same *kind* of fact in four
notations, upstream docs describe defaults while this repo rebinds over
them, and a sheet of upstream defaults alone says nothing about what a key
actually does on these hosts. Issue #371. The repo's overrides are read
straight out of the modules that declare them -- see read_repo_* below and
skill `keybinding-cheatsheet` (.agents/skills/) for where upstream defaults
live per tool and how to dump live bindings on-host.

    keybinding-cheatsheet.py kitty                     # repo bindings only
    keybinding-cheatsheet.py zsh dump.txt              # upstream input merged
    keybinding-cheatsheet.py bash -                    # upstream from stdin
    keybinding-cheatsheet.py kitty docs.md --format markdown-table --out sheet.md

TOOL is kitty, zsh, or bash (aliases ble, blesh). INPUT is a file (or - for
stdin) holding upstream defaults in one of these formats:

  kitty-source    kitty's options/definition.py `map(...)` entries
  bindkey         zsh bindkey lines -- a config file, or `bindkey -L` output.
                  Stateful: `bindkey -d` clears everything bound before it,
                  `-s` records a string translation, `-r` an unbind.
  ble-bind        ble-bind invocations found anywhere in the text (the repo's
                  sit inside `-C '...'` callbacks and a blehook string), and
                  dumps of the same command shape
  markdown-table  a pasted docs table, pipe-formatted or aligned plain text
  html-table      a pasted docs table as HTML
  auto            (default) sniff the above

Whatever the format, chords are normalized to one notation before rendering
(kitty_mod resolves against the configured value), the repo's overrides win
per chord, and an override that unbinds (`bindkey -r`, `ble-bind -f C-v -`)
replaces the upstream row with an explicit "unbound" so the sheet explains a
dead default instead of silently dropping it.

Kanata is deliberately not a tool here: kanata.nix only installs the
package; no defsrc/deflayer config exists anywhere in the repo to parse.
"""
import argparse
import html
import pathlib
import re
import shlex
import sys
from dataclasses import dataclass
from html.parser import HTMLParser

HERE  = pathlib.Path(__file__).resolve().parent
FLAKE = HERE.parent

KITTY_CONFIG = FLAKE / 'modules/packages/terminals/kitty/kitty-config.nix'
ZSH_BINDINGS = [FLAKE / 'modules/config-system/shell-config/zsh/config/initial-bindings.zsh',
                FLAKE / 'modules/config-system/shell-config/zsh/config/free-zellij-keys.zsh']
BLESH_NIX    = FLAKE / 'modules/config-system/shell-config/bash/blesh.nix'

# kitty's own default, applied when neither the input nor the repo config
# sets kitty_mod
KITTY_MOD_DEFAULT = 'ctrl+shift'

MOD_ORDER = ('ctrl', 'alt', 'shift', 'super', 'cmd')

# Control characters that get a friendlier name than Ctrl+<letter>. The 0x0d
# case is what makes the zsh4humans `bindkey -s '^[OM' '^M'` numpad-enter
# translation read as Enter.
CONTROL_NAMES = {0x00: 'ctrl+space', 0x09: 'tab', 0x0d: 'enter', 0x1b: 'escape'}

KEY_DISPLAY = {'up': 'Up', 'down': 'Down', 'left': 'Left', 'right': 'Right',
               'home': 'Home', 'end': 'End', 'insert': 'Insert', 'delete': 'Delete',
               'pageup': 'PageUp', 'pagedown': 'PageDown', 'backspace': 'Backspace',
               'escape': 'Escape', 'enter': 'Enter', 'tab': 'Tab', 'space': 'Space'}

# CSI final-byte tilde codes (xterm), letter finals, and rxvt's SS3 letters.
TILDE_KEYS = {'1': 'home', '2': 'insert', '3': 'delete', '4': 'end', '5': 'pageup',
              '6': 'pagedown', '7': 'home', '8': 'end',
              '11': 'f1', '12': 'f2', '13': 'f3', '14': 'f4', '15': 'f5',
              '17': 'f6', '18': 'f7', '19': 'f8', '20': 'f9', '21': 'f10',
              '23': 'f11', '24': 'f12'}
CSI_LETTERS = {'A': 'up', 'B': 'down', 'C': 'right', 'D': 'left', 'H': 'home', 'F': 'end'}
SS3_KEYS = {'A': 'up', 'B': 'down', 'C': 'right', 'D': 'left', 'H': 'home', 'F': 'end',
            'P': 'f1', 'Q': 'f2', 'R': 'f3', 'S': 'f4', 'M': 'enter'}

PLUS_MODS = {'ctrl': 'ctrl', 'control': 'ctrl', 'alt': 'alt', 'opt': 'alt',
             'option': 'alt', 'meta': 'alt', 'shift': 'shift', 'super': 'super',
             'cmd': 'cmd', 'command': 'cmd', 'kitty_mod': None}  # resolved at parse time
EMACS_MODS = {'C': 'ctrl', 'M': 'alt', 'S': 'shift', 's': 'super'}

# The vocabulary a bare word (no +, no prefix) may be as a key name. Deliberately
# closed: an open `[a-z]+` rule made any word -- a pasted table's header cells,
# for one -- parse as a chord. Extend here when a tool names a key differently.
KEY_ALIASES = {'esc': 'escape', 'del': 'delete', 'return': 'enter'}
KNOWN_KEYS = ({'enter', 'return', 'space', 'tab', 'escape', 'esc', 'backspace',
               'delete', 'del', 'insert', 'home', 'end', 'pageup', 'pagedown',
               'up', 'down', 'left', 'right', 'menu', 'plus', 'minus', 'clear'}
              | {f'f{n}' for n in range(1, 25)}
              | {f'kp_{n}' for n in range(10)}
              | {'kp_add', 'kp_subtract', 'kp_multiply', 'kp_divide', 'kp_enter',
                 'kp_decimal'})


# ── chord normalization ──────────────────────────────────────────────────────

class Chord:
    """One key chord in normalized form, or the raw spec if nothing decoded.

    The raw fallback matters: an escape sequence the decoder doesn't know
    must still reach the sheet verbatim rather than vanish. Sorting keeps
    decoded chords together and pushes raw ones to the end of a section.
    """

    __slots__ = ('mods', 'key', 'raw')

    def __init__(self, mods=(), key=None, raw=None):
        self.mods = frozenset(mods)
        self.key = key
        self.raw = raw

    @property
    def decoded(self):
        return self.raw is None

    def canonical(self):
        return (tuple(sorted(self.mods)), self.key) if self.decoded else ('raw', self.raw)

    def sort_key(self):
        if not self.decoded:
            return (1, self.raw)
        return (0, self.key, tuple(MOD_ORDER.index(m) for m in MOD_ORDER if m in self.mods))

    def __repr__(self):
        return f'<Chord {self.render()}>'

    def render(self):
        if not self.decoded:
            return self.raw
        parts = [m.capitalize() for m in MOD_ORDER if m in self.mods]
        key = self.key
        if len(key) == 1 and key.isalpha():
            parts.append(key.upper())
        elif len(key) == 1:
            parts.append(key)
        else:
            parts.append(KEY_DISPLAY.get(key, key.capitalize()))
        return '+'.join(parts)


def _from_control(code):
    """Control character (0x00-0x1f, or 0x7f) -> (mods, key-name)."""
    if code in CONTROL_NAMES:
        name = CONTROL_NAMES[code]
        return name.split('+', 1) if '+' in name else ('', name)
    if code == 0x7f:
        return ('', 'backspace')
    if code == 0x1f:
        return ('ctrl', '_')
    letter = chr(ord('a') + code - 1)
    if 'a' <= letter <= 'z':
        return ('ctrl', letter)
    return ('', f'ctrl-{code:#04x}')


def _decode_csi(params, final):
    """`ESC [` params final -- xterm CSI; xterm modifier param m = 1 + bitmask
    (1 shift, 2 alt/meta, 4 ctrl, 8 meta again for display purposes)."""
    nums = [int(p) if p.isdigit() else 0 for p in params.split(';') if p != ''] \
        if params else []
    if final in '^$':                     # rxvt: ^ = ctrl held, $ = shift held
        key = TILDE_KEYS.get(str(nums[0] if nums else 1))
        return Chord(['ctrl'] if final == '^' else ['shift'], key) if key else None
    mods = []
    bits = (nums[-1] - 1) if len(nums) > 1 and nums[-1] >= 1 else 0
    if bits & 1:
        mods.append('shift')
    if bits & 2 or bits & 8:
        mods.append('alt')
    if bits & 4:
        mods.append('ctrl')
    if final in CSI_LETTERS:
        return Chord(mods, CSI_LETTERS[final])
    if final == 'Z':
        return Chord(['shift'], 'tab')
    if final == '~':
        key = TILDE_KEYS.get(str(nums[0] if nums else 0))
        return Chord(mods, key) if key else None
    return None


def _decode_seq(seq):
    """Decode the character sequence a terminal would send into one Chord."""
    if not seq:
        return None
    if seq == '\x1b':
        return Chord([], 'escape')
    if seq.startswith('\x1b['):
        m = re.fullmatch(r'\x1b\[([0-9;]*)(.)', seq)
        return _decode_csi(m.group(1), m.group(2)) if m else None
    if seq.startswith('\x1bO'):
        ch = seq[2:]
        if ch in ('c', 'd'):              # ctrl+arrows in application mode
            return Chord(['ctrl'], 'right' if ch == 'c' else 'left')
        return Chord([], SS3_KEYS[ch]) if ch in SS3_KEYS else None
    if seq.startswith('\x1b'):
        rest = _decode_seq(seq[1:])
        if rest and rest.decoded and not rest.mods:
            # xterm: Meta+j sends ESC j, Meta+Shift+j sends ESC J -- the
            # capital carries the shift, so `^[K` is Alt+Shift+K, a chord
            # distinct from `^[k`
            mods, key = ['alt'], rest.key
            if len(key) == 1 and key.isalpha() and key.isupper():
                mods.append('shift')
                key = key.lower()
            return Chord(mods, key)
        return None
    if len(seq) == 1:
        code = ord(seq)
        if code < 0x20:
            mods, key = _from_control(code)
            return Chord([mods] if mods else [], key)
        if code == 0x7f:
            return Chord([], 'backspace')
        return Chord([], seq)
    return None


def _caret_to_seq(spec):
    """Expand bindkey caret notation into the raw character sequence.

    `^[` is escape, `^X` the control character, `^?` DEL; backslash escapes
    (`\\^`, `\\-`, `\\\\`) protect a literal next char -- which is how
    `'^[[3\\^'` reaches this parser intact from a quoted shell string.
    """
    out, i = [], 0
    while i < len(spec):
        c = spec[i]
        if c == '\\' and i + 1 < len(spec):
            out.append(spec[i + 1])
            i += 2
        elif c == '^' and i + 1 < len(spec):
            nxt = spec[i + 1]
            out.append('\x1b' if nxt == '[' else '\x7f' if nxt == '?'
                       else chr(ord(nxt.upper()) & 0x1f))
            i += 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def parse_plus(spec, kitty_mod=KITTY_MOD_DEFAULT):
    """kitty-style `+`-joined specs: ctrl+shift+s, kitty_mod+s, cmd+c."""
    parts = spec.lower().split('+')
    if not parts or '' in parts:
        return None
    key = parts[-1]
    # a kitty key is one character or a known bare word (enter, f5, space,
    # ...); anything else means this was not a `+`-joined spec after all --
    # e.g. a caret sequence like ^[[H, or a pasted table's header cell
    if len(key) != 1 and key not in KNOWN_KEYS:
        return None
    mods = []
    for part in parts[:-1]:
        if part not in PLUS_MODS:
            return None
        resolved = kitty_mod if PLUS_MODS[part] is None else PLUS_MODS[part]
        mods.extend(resolved.split('+'))
    return Chord(mods, key)


def parse_emacs(spec):
    """emacs/ble.sh specs: C-r, M-x, C-v; chained prefixes like C-S-r."""
    m = re.fullmatch(r'((?:[CMSs]-)+)(.+)', spec)
    if not m:
        return None
    key = m.group(2).lower()
    if len(key) != 1 and not key.isalnum():
        return None
    return Chord([EMACS_MODS[p] for p in m.group(1).split('-')[:-1]], key)


def parse_caret(spec):
    """zsh bindkey specs: ^R, ^[[H, ^[[1;5C, ^[Oc, and \\e[1;5C (`bindkey -L`)."""
    if not re.search(r'\^|\\', spec):
        return None
    if spec.startswith('\\e'):
        spec = '^[' + spec[2:]
    chord = _decode_seq(_caret_to_seq(spec))
    return chord if chord and chord.decoded else None


def parse_chord(spec, kitty_mod=KITTY_MOD_DEFAULT):
    """One key spec in any supported notation -> Chord, or None.

    Unrecognizable input returns None (callers skip the row); input that is
    *recognizably a key attempt* but undecodable (an escape sequence with an
    unknown form) returns a raw Chord so it still reaches the sheet.
    """
    if spec is None:
        return None
    spec = spec.strip().strip('`').strip('"').strip("'")
    if not spec:
        return None
    for attempt in (lambda s: parse_plus(s, kitty_mod), parse_emacs, parse_caret):
        chord = attempt(spec)
        if chord and chord.decoded:
            return chord
    if len(spec) == 1:
        return Chord([], spec.lower())
    lowered = spec.lower()
    if lowered in KNOWN_KEYS:
        return Chord([], KEY_ALIASES.get(lowered, lowered))
    if re.search(r'\^|\\', spec):
        return Chord(raw=spec)
    return None


# ── one internal representation ──────────────────────────────────────────────

@dataclass
class Binding:
    tool: str
    mode: str            # keymap/mode context; '' where the tool has none
    chord: Chord
    action: str | None   # None = unbound
    source: str          # 'repo <path>' or 'upstream <where>'
    notes: str | None = None

    @property
    def unbound(self):
        return self.action is None


# ── source-format parsers: (text, tool, source) -> [Binding] ────────────────

def parse_kitty_source(text, tool, source, kitty_mod=KITTY_MOD_DEFAULT):
    """kitty options/definition.py `map('kitty_mod+s', 'action')` entries.

    Entries are cut on call boundaries (one `map(` to the next) rather than
    matched in a single regex, so a `long_text=` on a following line attaches
    to its own entry and an entry without one cannot steal the next entry's.
    """
    starts = [m.start() for m in re.finditer(r'\bmap\(', text)]
    out = []
    for i, start in enumerate(starts):
        span = text[start:starts[i + 1] if i + 1 < len(starts) else len(text)]
        head = re.match(r"map\(\s*'([^']+)'\s*,\s*'([^']+)'", span)
        if not head:
            continue
        chord = parse_chord(head.group(1), kitty_mod)
        if not chord:
            continue
        desc = re.search(r"long_text='([^']*)'", span)
        out.append(Binding(tool, '', chord, head.group(2), source,
                           desc.group(1) if desc else None))
    return out


def _rows_to_bindings(rows, tool, source, kitty_mod=KITTY_MOD_DEFAULT):
    """Shared row logic for the pasted-table formats.

    A row counts as a binding when one cell parses as a chord; the action is
    the neighbouring cell, whichever side of the key it sits on (kitty's docs
    put Action before Shortcut, hand-kept tables usually the reverse).
    """
    out = []
    for cells in rows:
        cells = [html.unescape(c.replace('`', '').strip()) for c in cells if c.strip()]
        if len(cells) < 2:
            continue
        key_at = next((i for i, c in enumerate(cells) if parse_chord(c, kitty_mod)), None)
        if key_at is None:
            continue
        action_at = key_at + 1 if key_at + 1 < len(cells) else 0
        out.append(Binding(tool, '', parse_chord(cells[key_at], kitty_mod),
                           cells[action_at], source))
    return out


def parse_markdown_table(text, tool, source, **_):
    """Pasted docs as a pipe table or aligned plain text."""
    rows = []
    for line in text.splitlines():
        s = line.strip()
        if not s or set(s) <= set('|-: '):
            continue
        rows.append([c.strip() for c in s.strip('|').split('|')] if '|' in s
                    else re.split(r'\s{2,}', s))
    return _rows_to_bindings(rows, tool, source)


class _TableHTML(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows, self._row, self._cell, self._in_cell = [], None, None, False

    def handle_starttag(self, tag, attrs):
        if tag == 'tr':
            self._row = []
        elif tag in ('td', 'th') and self._row is not None:
            self._cell, self._in_cell = [], True

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self._in_cell:
            self._row.append(''.join(self._cell))
            self._in_cell = False
        elif tag == 'tr' and self._row is not None:
            if self._row:
                self.rows.append(self._row)
            self._row = None

    def handle_data(self, data):
        if self._in_cell:
            self._cell.append(data)


def parse_html_table(text, tool, source, **_):
    """Pasted docs as an HTML table (stdlib parser, no dependencies)."""
    parser = _TableHTML()
    parser.feed(text)
    return _rows_to_bindings(parser.rows, tool, source)


def strip_comment(line):
    """Drop a trailing shell comment; '#' inside quotes is data, not a comment."""
    quote = None
    for i, c in enumerate(line):
        if quote:
            if c == quote:
                quote = None
        elif c in ('"', "'"):
            quote = c
        elif c == '#':
            return line[:i]
    return line


def parse_bindkey(text, tool, source, **_):
    """zsh bindkey lines, stateful and in order.

    `-d` deletes every keymap -- bindings before it in the file are dead and
    correctly fall off the sheet (initial-bindings.zsh leans on this: its
    Manjaro block is wiped by the zsh4humans `bindkey -d`). `-s` records a
    string translation, rendered as "sends X" with one-hop resolution to the
    widget X lands on. `-r` unbinds, kept as an explicit tombstone row. Keys
    that cannot be decoded -- the dynamic `"${terminfo[khome]}"` guards --
    are skipped; the static fallback forms alongside them bind the same
    physical keys.
    """
    mode = 'main'
    state = {mode: {}}            # mode -> {canonical chord: Binding}
    translations = {}             # (mode, canonical) -> raw target of `bindkey -s`

    def record(binding):
        state.setdefault(binding.mode, {})[binding.chord.canonical()] = binding

    for raw_line in text.splitlines():
        line = strip_comment(raw_line).strip()
        if not line:
            continue
        try:
            tokens = shlex.split(line, posix=True)
        except ValueError:
            continue
        if not tokens or tokens[0] != 'bindkey':
            continue
        flags, positional = [], []
        args = tokens[1:]
        i = 0
        while i < len(args):
            if args[i].startswith('-') and len(args[i]) > 1:
                flags.append(args[i])
                if args[i] in ('-N', '-m') and i + 1 < len(args):
                    i += 1
                    positional.append(args[i])
            else:
                positional.append(args[i])
            i += 1
        if '-d' in flags:
            mode = 'main'
            state = {'main': {}}
            continue
        if '-e' in flags:
            mode = 'main'
            continue
        if '-a' in flags:
            mode = 'vicmd'
            continue
        if '-N' in flags and positional:
            mode = positional.pop(0)
            state.setdefault(mode, {})
            continue
        if '-m' in flags or not positional:
            continue
        chord = parse_chord(positional[0])
        if chord is None:
            continue
        if '-r' in flags:
            record(Binding(tool, mode, chord, None, source))
        elif '-s' in flags and len(positional) >= 2:
            record(Binding(tool, mode, chord, None, source, f'sends {positional[1]}'))
            translations[(mode, chord.canonical())] = positional[1]
        elif len(positional) >= 2:
            record(Binding(tool, mode, chord, positional[1], source))

    # one-hop: name what a surviving translation's target lands on. A real
    # binding on the same chord overwrote the translation row in state --
    # nothing left to annotate there.
    for (send_mode, canonical), target in translations.items():
        binding = state.get(send_mode, {}).get(canonical)
        if binding is None or not (binding.notes or '').startswith('sends'):
            continue
        target_chord = parse_chord(target)
        resolved = target_chord and state.get(send_mode, {}).get(target_chord.canonical())
        if resolved and resolved.action:
            binding.notes += f' -> {resolved.action}'
    return [b for table in state.values() for b in table.values()]


def parse_ble_bind(text, tool, source, **_):
    """ble-bind invocations found anywhere in the text.

    The repo's bindings are not top-level lines: they ride inside `-C '...'`
    callbacks of a ble-import and a blehook string (blesh.nix), so this
    scans for occurrences of the command rather than matching whole lines.
    Regions are cut at single quotes/newlines (double quotes belong to the
    command's own arguments), and a region holding several commands is split
    on ';'. `-f KEY -` (dash widget) is an unbind.
    """
    out = []
    starts = [m.start() for m in re.finditer(r'ble-bind\b', text)]
    for idx, start in enumerate(starts):
        region = text[start:starts[idx + 1] if idx + 1 < len(starts) else len(text)]
        for boundary in ("'", '\n'):
            p = region.find(boundary)
            if p != -1:
                region = region[:p]
        for command in region.split(';'):
            command = command.strip()
            if not command.startswith('ble-bind'):
                continue
            try:
                tokens = shlex.split(command, posix=True)
            except ValueError:
                tokens = command.split()
            mode, key, action, unbind = '', None, None, False
            i = 1                                      # tokens[0] is 'ble-bind'
            while i < len(tokens):
                if tokens[i] == '-m' and i + 1 < len(tokens):
                    mode = tokens[i + 1]
                    i += 2
                elif tokens[i] in ('-f', '-x') and i + 2 < len(tokens):
                    key, action, unbind = tokens[i + 1], tokens[i + 2], tokens[i + 2] == '-'
                    i += 3
                else:
                    i += 1
            if key is None:
                continue
            chord = parse_chord(key) or Chord(raw=key)
            out.append(Binding(tool, mode, chord,
                               None if unbind else action, source))
    return out


PARSERS = {'kitty-source': parse_kitty_source,
           'markdown-table': parse_markdown_table,
           'html-table': parse_html_table,
           'bindkey': parse_bindkey,
           'ble-bind': parse_ble_bind}


def sniff_format(text):
    if re.search(r"\bmap\(\s*'", text):
        return 'kitty-source'
    if text.lstrip().startswith('<') or '<table' in text:
        return 'html-table'
    if 'ble-bind' in text:
        return 'ble-bind'
    if re.search(r"^\s*'?bindkey\b", text, re.M):
        return 'bindkey'
    return 'markdown-table'


# ── this repo's overrides, read straight from the declaring modules ─────────

def kitty_mod_from_config():
    """The configured kitty_mod, or kitty's default. extraConfig is a plain
    setting line (`kitty_mod ctrl+shift`), not a binding, so it is read
    rather than parsed by the keybindings logic."""
    m = re.search(r'kitty_mod\s+([a-z+]+)', KITTY_CONFIG.read_text())
    return m.group(1) if m else KITTY_MOD_DEFAULT


def read_repo_kitty():
    text = KITTY_CONFIG.read_text()
    mod = kitty_mod_from_config()
    out = []
    block = re.search(r'keybindings\s*=\s*\{(.*?)\}', text, re.S)
    if block:
        for m in re.finditer(r'"([^"]+)"\s*=\s*"([^"]+)"', block.group(1)):
            chord = parse_chord(m.group(1), mod)
            if chord:
                out.append(Binding('kitty', '', chord, m.group(2),
                                   f'repo {KITTY_CONFIG.relative_to(FLAKE)}'))
    return out


def read_repo_zsh():
    text = '\n'.join(p.read_text() for p in ZSH_BINDINGS)
    source = 'repo ' + ZSH_BINDINGS[0].parent.relative_to(FLAKE).as_posix() + '/*.zsh'
    return parse_bindkey(text, 'zsh', source)


def read_repo_bash():
    return parse_ble_bind(BLESH_NIX.read_text(), 'bash',
                          f'repo {BLESH_NIX.relative_to(FLAKE)}')


TOOLS = {'kitty': (read_repo_kitty,
                   "kitty's options/definition.py map(...) entries, or a pasted shortcut table"),
         'zsh': (read_repo_zsh,
                 '`bindkey -L` output from a live shell, or the pinned zsh\'s ZLE docs'),
         'bash': (read_repo_bash,
                  "ble-bind dump from a live shell, or ble.sh's keymap docs")}
ALIASES = {'ble': 'bash', 'blesh': 'bash'}

MODE_ORDER = {'main': 0, 'emacs': 1, 'vi_imap': 2, 'vicmd': 3}


# ── merge + render ───────────────────────────────────────────────────────────

def merge(upstream, overrides):
    """Repo overrides win per (mode, chord); an override that unbinds leaves
    an explicit tombstone rather than silently dropping the upstream row."""
    merged = {}
    for binding in upstream + overrides:
        merged[(binding.mode, binding.chord.canonical())] = binding
    return list(merged.values())


def render_markdown(tool, bindings, kitty_mod=None):
    by_mode = {}
    for b in bindings:
        by_mode.setdefault(b.mode or 'default', []).append(b)
    lines = [f'# Keybinding cheat sheet — {tool}', '']
    if kitty_mod:
        lines += [f'kitty_mod resolves to `{kitty_mod}` (from the repo config).', '']
    for mode in sorted(by_mode, key=lambda m: (MODE_ORDER.get(m, 9), m)):
        rows = sorted(by_mode[mode], key=lambda b: b.chord.sort_key())
        if len(by_mode) > 1:
            lines += [f'## mode: {mode}', '']
        lines += ['| Key | Action | Notes | Source |',
                  '| --- | --- | --- | --- |']
        for b in rows:
            if b.unbound and b.notes and b.notes.startswith('sends '):
                action, notes = f"`{b.notes}`", ''   # a translation is an action, not an unbind
            elif b.unbound:
                action, notes = '*(unbound)*', ''
            else:
                action, notes = f'`{b.action}`', b.notes or ''
            lines.append(f'| {b.chord.render()} | {action} | {notes} | {b.source} |')
        lines.append('')
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('tool', help='kitty, zsh, or bash (aliases: ble, blesh)')
    parser.add_argument('input', nargs='?',
                        help='file with upstream defaults, or - for stdin; omit for repo-only')
    parser.add_argument('--format', choices=sorted(PARSERS), default='auto',
                        help='input format (default: auto-detect)')
    parser.add_argument('--out', type=pathlib.Path, help='write markdown here (default: stdout)')
    args = parser.parse_args(argv)

    tool = ALIASES.get(args.tool, args.tool)
    if tool not in TOOLS:
        parser.error(f'unknown tool {args.tool!r} -- one of: {", ".join(sorted(TOOLS))}')

    overrides = TOOLS[tool][0]()
    upstream = []
    if args.input:
        text = sys.stdin.read() if args.input == '-' else pathlib.Path(args.input).read_text()
        fmt = sniff_format(text) if args.format == 'auto' else args.format
        where = 'stdin' if args.input == '-' else pathlib.Path(args.input).name
        upstream = PARSERS[fmt](text, tool, f'upstream {where} ({fmt})')

    mod = kitty_mod_from_config() if tool == 'kitty' else None
    sheet = render_markdown(tool, merge(upstream, overrides), kitty_mod=mod)
    if args.out:
        args.out.write_text(sheet)
    else:
        sys.stdout.write(sheet)


if __name__ == '__main__':
    main()
