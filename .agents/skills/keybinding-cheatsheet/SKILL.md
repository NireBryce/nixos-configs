---
name: keybinding-cheatsheet
description: Generates a normalized keybinding cheat sheet for a tool, and shows how to teach the generator a new input format.
when_to_use: Asked what a chord does in kitty, zsh, or bash with ble.sh, or to merge upstream keybinding defaults with this repo's overrides.
---

# Keybinding cheat sheets

## Applies to

| Trigger | Use this |
| --- | --- |
| "what does `<chord>` do" for kitty, zsh, or bash+ble.sh | run the generator (below) |
| merging upstream defaults against this repo's overrides | the generator does exactly this |
| a new upstream/docs format the parser rejects or mangles | "Adding a new input format" |
| changing the bindings themselves | skill `home-manager-dotfiles`; this skill only reads them |
| Homebrew overlap for a package | skill `package-platform-support`; unrelated to chords |

## Quick start

```sh
just keybindings kitty            # repo bindings only
just keybindings zsh dump.txt     # upstream input merged under repo overrides
just keybindings bash --format bindkey - --out sheet.md   # stdin, explicit format
just keybindings-test             # the fixture tests
```

Tools: `kitty`, `zsh`, `bash` (aliases `ble`, `blesh`). The format is auto-detected; `--format` overrides. Chords render in one notation (`kitty_mod+s`, `C-r` and `^[[1;5C` all normalize). Repo overrides win per chord. An override that unbinds a chord shows as an explicit `*(unbound)*` row.

## Finding upstream defaults

1. **Use the pinned version.** HEAD does not match what hosts run. Resolve the rev:

   ```sh
   jq -r '.nodes["root"].inputs.nixpkgs as $id | .nodes[$id].locked.rev' flake/flake.lock
   ```

   Fetch the source at that rev (GitHub tarball), not a fresh clone. For non-nixpkgs tools (ble.sh), do the same lookup on the tool's own input name.

2. **Find each tool's defaults:**
   - *kitty*: `map(...)` entries in `kitty/options/definition.py` of the pinned kitty source (parser: `kitty-source`, including `long_text=` descriptions), or the docs shortcut table pasted as markdown/HTML.
   - *zsh*: take ZLE's built-in widget defaults from a live `bindkey -L` (or `bindkey -M main -L`) on a host rather than from the source. The parser takes that output as-is.
   - *bash/ble.sh*: run `ble-bind -P` in a live shell. The parser accepts the `ble-bind -m MODE -f KEY WIDGET` command form. Check the dump's actual shape on the host first; if it differs, it is a new format (walkthrough below), and the sheet must not be corrected by eye.

3. Prefer a live dump over source when keys resolve dynamically (terminfo, terminal protocol variants).

## This repo's overrides — where to look

The generator reads these files. Grep them when auditing by hand.

| Tool | Files | What's there |
| --- | --- | --- |
| kitty | `flake/modules/packages-config/terminals/kitty/kitty-config.nix` | `programs.kitty.keybindings` attrset. `kitty_mod` is a setting in `extraConfig` that the script resolves; it is not a literal chord prefix |
| zsh | `flake/modules/general-config/shell-config/zsh/config/initial-bindings.zsh` and `.../free-zellij-keys.zsh` | the bindkey blocks, interpolated into `programs.zsh.initContent` in `zsh.nix` via `lib.fileContents`; grep the `config/` files, not only `zsh.nix` |
| bash | `flake/modules/general-config/shell-config/bash/blesh.nix` | ble-bind inside `-C` callbacks of a `ble-import` and a `blehook ATTACH+=` string. Quoting is nested, so a line-start grep for `ble-bind` finds nothing |

Known traps:

- **zsh's `bindkey -d` wipes every binding before it.** The Manjaro block at the top of `initial-bindings.zsh` is dead config, because the zsh4humans block resets the keymaps mid-file. The parser is stateful and models this; a plain grep of the file reports bindings that do not exist.
- **`bindkey -s` lines are string translations, not widget bindings**, and `-r` lines are intentional unbinds (the zellij copy/paste keys). Each gets its own row in the sheet; do not read them as widgets.
- **kanata.nix has no bindings.** It only installs the package, and no defsrc/deflayer exists in the repo, so kanata is not a tool here.
- **fzf's C-r is disabled** (empty `command` in `flake/modules/packages-config/shell-apps/find/fzf.nix`) in favor of atuin's `__atuin_history`, which the blesh `-C` callbacks bind. If a pasted fzf doc lists C-r, the sheet correctly shows the repo's override.
- **Reading a generated dotfile back gives false negatives.** Wrong attribute names return empty, some entries are `.source` not `.text`, and `types.lines` concatenation means one dotfile is not one module. See skill `home-manager-dotfiles`; use `just dotfiles` / `just dotfile ./.zshrc`.

## Adding a new input format

1. **Collect the quirks from a real sample first**: quote style, key notation, mode prefixes, unbind syntax, ordering like `bindkey -d`. A made-up fixture passes while the real doc fails.
2. **Write a parser** in `flake/scripts/keybinding-cheatsheet.py`: `parse_<format>(text, tool, source, **_) -> [Binding]`. Register it in the `PARSERS` dict; registration is what adds the `--format` choice.
3. **Put new chord notation in the normalizer, not the parser.** Extend `parse_plus`/`parse_emacs`/`parse_caret` (or the CSI decoder behind `parse_caret`) and, for a newly named key, `KNOWN_KEYS`. All formats share `parse_chord`, so a notation fixed there is fixed everywhere. A sequence that cannot be decoded must return a raw `Chord`, shown verbatim on the sheet, never a guess.
4. **Add a fixture class** in `flake/scripts/tests/test_keybinding_cheatsheet.py`, following the existing ones: a real-shaped sample, the happy path, and the awkward row (header cell, dynamic key, unbind). Run `just keybindings-test`; `just preflight` runs it from then on.
5. **Teach the sniffer** (`sniff_format` in the same file) if the format is detectable. Otherwise users must pass `--format`.
6. **Record the quirks** under Format quirks below.

## Format quirks

- *bindkey*: stateful, and `-d` wipes all prior bindings. Both the quoted-word form (`'bindkey'`) and the plain form appear. `-s` sends strings and `-r` unbinds. Dynamic keys like `"${terminfo[khome]}"` are skipped, since static fallback forms bind the same physical keys. In caret notation ESC + uppercase letter is alt+shift, a different chord from ESC + lowercase.
- *ble-bind*: occurrences are matched anywhere in the text (repo bindings sit inside `-C '...'` and `blehook` strings). Regions are cut at single quotes and newlines, so double-quoted command args survive. `-f KEY -` is an unbind. `-x` actions are shell commands, not widget names.
- *kitty*: `kitty_mod` resolves against the setting line in `extraConfig` (default `ctrl+shift`). `cmd` is a darwin-only modifier and stays distinct from `super`. Docs tables put the Action column before the Shortcut column, and the parser handles either order. Bare-word keys must be in `KNOWN_KEYS` or they are treated as prose (table headers).
- *Undecodable sequences* render verbatim in a raw row, sorted last. A raw row is a to-do for the normalizer; do not delete it.

## See also

- skill `home-manager-dotfiles`: editing what this sheet reads
- `wiki/config-structure/categories/shell-config/blesh.md`: why the ble-bind lines are shaped the way they are
