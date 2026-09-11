# blesh, for agents

_Last modified: 2026-09-11_

Condensed from [blesh.md](blesh.md), which keeps the diagnosis narrative and
the evidence trail. Facts only here.

`ble.sh` is wired by hand — **there is no `programs.bash.blesh.enable` in
Home Manager.** Package, `source ble.sh --attach=none` early in
`initContent`, and `ble-attach` at the end live in `bash.nix`; the `.blerc`
is `nire/shell-config/bash/blesh.nix`.

## What it wires together

| Tool | Owns |
|---|---|
| carapace | most completion candidates — see [carapace.md](carapace.md) |
| fzf | the completion menu (`fzf-menu.bash`), Ctrl-T, Alt-C |
| atuin | Ctrl-R |
| bash-completion / nix-completion | ble.sh contrib, loaded **first** |

## Load-order rules

- **bash-completion loads before the fzf integrations** (ble.sh's own
  requirement).
- **`fzf-key-bindings.bash` loads via a `-C` callback, not `ble-import`**,
  so it lands after `ble-attach` imported atuin's Ctrl-R. fzf's Ctrl-R is
  then **rebound** back to atuin with two `ble-bind -x` calls — rebound, not
  unbound: a keymap with no entry for a key does nothing, it does not fall
  through.
- **`complete_auto_menu` must stay unset.** It is an idle-delay knob, not a
  boolean; `1` means "open the fzf menu one tick after every keystroke",
  which on real hardware looks like Tab being held down.

## Where a binding has to live, and why

Three channels, and which one works depends on whether the key's keycode is
fixed:

| Key | Channel | Why |
|---|---|---|
| C-v unbind | `blehook ATTACH+='ble-bind …'` | `.blerc` is sourced *before* `ble-attach` installs default keymaps, so a plain top-level `ble-bind` is overwritten. Works because C-v's keycode is fixed. |
| `focus`/`blur` no-op | a **real readline `bind`** in `bash.nix`'s last initExtra block, pre-attach | synthetic-key names get **dynamically assigned keycodes in first-registration order**, so *any* `ble-bind` made before `ble-attach`'s final key-table build lands under a keycode that is later reassigned and silently stops matching. All three `ble-bind` routes tested and failed. It also cannot live in `.blerc` — ble.sh has already wrapped the `bind` builtin by then. |

The focus/blur symptom, if it comes back: konsole rings audibly plus an
`unbound keyseq: focus` bell on every tab switch, because mode-1004 focus
reporting sends `CSI I`/`CSI O` and ble.sh binds those in no keymap of any
version.

## The carapace `read` bug

Symptom: stray ``bash: read: `': not a valid identifier`` alongside an
otherwise-correct completion menu, on Tab and on auto-complete.

Cause: ble.sh's `_ble_builtin_read_hook` cancellation net redirects any
in-flight `read` through `ble/bash/read "$@" < /dev/null; return 148` when
the user is still typing — the **common** case during fast typing, not an
edge case. Caught against carapace's own read line, `"$@"` comes back split
character-by-character. **Not caused by `carapace-desc.bash`** — confirmed
twice, independently.

Fix, in the tree and switch-confirmed:
`carapace-completer-read-fix.bash` patches `_carapace_completer` via
`declare -f` plus textual substitution, replacing the `read` with parameter
expansion. Sourced from `bash.nix` after `source <(carapace _carapace bash)`
and before `carapace-desc.bash`. Closed as issue #72; removing it once
upstream fixes the bug is issue #75.

**carapace's visible `IFS=''` is an invisible SOH byte, not an empty
string.** Check with `od -c`; misreading it derailed this diagnosis once.

**Do not file this upstream** without Elly saying so explicitly first
(`AGENTS.md`).

## See also

[blesh.md](blesh.md) · [carapace.md](carapace.md) · [README.md](README.md) ·
[../../open-threads.md](../../open-threads.md)
