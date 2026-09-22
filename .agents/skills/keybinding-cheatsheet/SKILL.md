---
name: keybinding-cheatsheet
description: How to generate a normalized keybinding cheat sheet for a tool and teach the generator a new input format.
---

# Keybinding cheat sheets

## Applies to

| Trigger | Use this |
| --- | --- |
| "what does `<chord>` actually do" for kitty, zsh, or bash+ble.sh | run the generator (below) |
| merging upstream defaults against this repo's overrides | same — that is the generator's whole job |
| a new upstream/docs format the parser rejects or mangles | "Adding a new input format" |
| changing the bindings themselves | skill `home-manager-dotfiles` — this only *reads* them |
| Homebrew overlap for a package | skill `nirepackages-platform-support` — unrelated to chords |

## Quick start

```sh
just keybindings kitty            # repo bindings only
just keybindings zsh dump.txt     # upstream input merged under repo overrides
just keybindings bash --format bindkey - --out sheet.md   # stdin, explicit format
just keybindings-test             # the fixture tests
```

Tools: `kitty`, `zsh`, `bash` (aliases `ble`, `blesh`). Input format is
auto-sniffed; `--format` overrides. Chords render normalized
(`kitty_mod+s`, `C-r`, `^[[1;5C` all resolve to the same notation), repo
overrides win per chord, and an override that unbinds shows as an explicit
`*(unbound)*` row instead of silently dropping the upstream default.

## Finding upstream defaults

1. **Prefer the pinned version.** Upstream HEAD lies about what these hosts
   run. Resolve the rev first:

   ```sh
   jq -r '.nodes["root"].inputs.nixpkgs as $id | .nodes[$id].locked.rev' flake/flake.lock
   ```

   Fetch the tool's source at that rev (GitHub tarball pinned to it), not a
   fresh clone. For tools not packaged via nixpkgs (ble.sh via its own
   input), the same lookup works on its input name.

2. **Per tool, the defaults live here:**
   - *kitty* — `map(...)` entries in `kitty/options/definition.py` of the
     pinned kitty source (parser: `kitty-source`, incl. `long_text=`
     descriptions), or the docs shortcut table pasted as markdown/HTML.
   - *zsh* — ZLE's built-in widget defaults are best taken from a live
     `bindkey -L` (or `bindkey -M main -L`) on a host, not from source
     reading; the parser takes that output as-is.
   - *bash/ble.sh* — `ble-bind -P` from a live shell. The parser accepts
     the `ble-bind -m MODE -f KEY WIDGET` command form; **verify the dump's
     actual shape on-host first** — if it differs, that is a new format
     (walkthrough below), not a reason to eyeball the sheet.

3. A live dump beats source reading whenever the tool resolves keys
   dynamically (terminfo lookups, terminal protocol variants).

## This repo's overrides — where to look

The generator reads these directly; grep them when auditing by hand.

| Tool | Files | What's there |
| --- | --- | --- |
| kitty | `flake/modules/packages/terminals/kitty/kitty-config.nix` | `programs.kitty.keybindings` attrset; `kitty_mod` is a *setting* in `extraConfig`, resolved by the script, never a chord prefix to take literally |
| zsh | `flake/modules/config-system/shell-config/zsh/config/initial-bindings.zsh` and `.../free-zellij-keys.zsh` | the bindkey blocks; interpolated into `programs.zsh.initContent` in `zsh.nix` via `lib.fileContents`, so grep the `config/` files, not only `zsh.nix` |
| bash | `flake/modules/config-system/shell-config/bash/blesh.nix` | ble-bind inside `-C` callbacks of a `ble-import` and a `blehook ATTACH+=` string; nested quoting, so a line-start grep for `ble-bind` finds nothing |

Traps that have bitten here:

- **zsh's `bindkey -d` wipes everything before it.** The Manjaro block at
  the top of `initial-bindings.zsh` is dead config — the zsh4humans block
  resets the keymaps mid-file. The parser is stateful and models this; a
  naive grep of the file reports bindings that do not exist.
- **`bindkey -s` lines are string translations, not widget bindings**, and
  `-r` lines are deliberate unbinds (the zellij copy/paste keys). Both get
  their own row in the sheet; do not read them as widgets.
- **kanata.nix has no bindings** — it only installs the package. No
  defsrc/deflayer exists anywhere in the repo, so kanata is not a tool here.
- **fzf's C-r is disabled on purpose** (empty `command` in
  `flake/modules/packages/shell-apps/find/fzf.nix`) in favor of atuin's
  `__atuin_history`, which is what the blesh `-C` callbacks bind. If a
  pasted fzf doc lists C-r, the sheet correctly shows the repo's override.
- **Reading the generated dotfile back is a false-negative machine** —
  wrong attribute names return empty, some entries are `.source` not
  `.text`, and `types.lines` concatenation means one dotfile is not one
  module. Skill `home-manager-dotfiles` holds the full mechanism; for
  reading generated output use `just dotfiles` / `just dotfile ./.zshrc`.

## Adding a new input format

1. **Nail the format's quirks first** (quote style, key notation, mode
   prefixes, unbind syntax, ordering semantics like `bindkey -d`), from a
   real sample — a fixture of imagination passes while the real doc fails.
2. **Write a parser** in `flake/scripts/keybinding-cheatsheet.py`:
   `parse_<format>(text, tool, source, **_) -> [Binding]`, and register it
   in the `PARSERS` dict — registration is what adds the `--format` choice.
3. **New chord notation goes in the normalizer, not the parser**:
   extend `parse_plus`/`parse_emacs`/`parse_caret` (or the CSI decoder
   behind `parse_caret`) and, for a newly named key, `KNOWN_KEYS`. All
   formats share `parse_chord`; a notation fixed in one parser is fixed
   everywhere. A sequence that will not decode must return a raw `Chord` —
   verbatim on the sheet — never a guess.
4. **Add a fixture class** in `flake/scripts/test_keybinding_cheatsheet.py`,
   following the existing ones: real-shaped sample, the happy path, plus
   the ugly row (header cell, dynamic key, unbind). Run `just
   keybindings-test`; `just preflight` runs it from now on.
5. **Teach the sniffer** (`sniff_format` in the same file) if the format is
   detectable; otherwise `--format` carries the weight.
6. **Record the quirks here**, under Format quirks below — the next agent
   should not rediscover that `-C` callbacks nest quotes or that ESC +
   uppercase letter means alt+shift.

## Format quirks

- *bindkey* — stateful: `-d` wipes all prior bindings; `'bindkey'`
  quoted-word form and plain form both appear; `-s` sends strings, `-r`
  unbinds; `"${terminfo[khome]}"`-style dynamic keys are skipped (static
  fallback forms bind the same physical keys); in caret notation ESC +
  uppercase letter is alt+shift, a chord distinct from ESC + lowercase.
- *ble-bind* — occurrences are matched anywhere in the text (repo bindings
  sit inside `-C '...'` and `blehook` strings); regions cut at single
  quotes/newlines, so double-quoted command args survive; `-f KEY -` is an
  unbind; `-x` actions are shell commands, not widget names.
- *kitty* — `kitty_mod` resolves against `extraConfig`'s setting line
  (default `ctrl+shift`); `cmd` is a darwin-only modifier and stays
  distinct from `super`; docs tables put the Action column before the
  Shortcut column and the parser handles either order; bare-word keys must
  be in `KNOWN_KEYS` or they are treated as prose (table headers).
- *Undecodable sequences render verbatim* in a raw row, sorted last —
  treat a raw row as a to-do for the normalizer, not noise to delete.

## See also

- skill `home-manager-dotfiles` — editing what this sheet reads
- `wiki/categories/shell-config/blesh.md` — why the ble-bind lines are
  shaped the way they are
