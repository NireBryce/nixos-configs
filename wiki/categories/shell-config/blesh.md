# blesh (bash line editor)

`ble.sh` is wired up by hand for bash — there's no Home Manager option for
it (`programs.bash.blesh.enable` doesn't exist; see
[shell-config](README.md)). The package, `source ble.sh
--attach=none` early in `initContent`, and `ble-attach` at the end all live
in `bash.nix`; the `.blerc` config itself is owned by
[`bash/blesh.nix`](../../../flake/modules/nire/shell-config/bash/blesh.nix).

## Plugins

The `.blerc` doesn't add editing behavior of its own so much as it wires
together external completion/history tools underneath ble.sh's UI:

- **carapace** — the actual source of most completion candidates. Enough
  was learned about how it's installed, how its generated bash completer
  works internally, and how it avoids clobbering (and being clobbered by)
  `cod`'s daemon-based completions, that it has its own page:
  [carapace](carapace.md).
- **fzf** — renders the completion menu (`fzf-menu.bash`) and keeps its own
  Ctrl-T/Alt-C bindings, but not Ctrl-R (see atuin below). Package and
  config: [`fzf.nix`](../../../flake/modules/nirePackages/shell-apps/find/fzf.nix).
- **atuin** — owns Ctrl-R for history search; see the `-C` callback
  ordering note below for how it wins that key back from fzf. Package and
  config: [`atuin.nix`](../../../flake/modules/nirePackages/shell-apps/history/atuin.nix).
- **bash-completion** / **nix-completion** — ble.sh's own contrib
  integrations, loaded first per ble.sh's own note that bash-completion
  must come before the fzf integrations.

## What the `.blerc` actually wires together

- **`bash-completion.bash`** and **`nix-completion.bash`** — loaded first,
  per ble.sh's own note that bash-completion must come before the fzf
  integrations.
- **[`carapace-desc.bash`](../../../flake/modules/nire/shell-config/bash/carapace-desc.bash)**
  (this repo, 2026-08-22) — advises carapace's `_carapace_completer` with
  ble.sh's `after`-type function advice, so that after carapace's plain
  `COMPREPLY` word list comes back, it re-derives per-candidate descriptions
  from `carapace <cmd> export -- <words...>` (JSON) and re-yields them
  through `ble/complete/cand/yield`, which is what `bleopt
  complete_menu_style=desc` reads. If the `export` call or the JSON parse
  ever fails, `COMPREPLY` is left untouched and candidates silently fall
  back to carapace's plain word list — same as before this file existed.
  Full detail on what it's advising and why: [carapace](carapace.md).
- **`fzf-menu.bash`** / **`fzf-completion.bash`** — render the completion
  menu through fzf (the zsh-fzf-tab equivalent). `complete_auto_menu` must
  stay unset here — it's an idle-delay knob, not a boolean, and setting it
  to `1` means "open the fzf menu one tick after every keystroke," which on
  real hardware looked exactly like Tab being held down. Full mechanism in
  the file's own comment.
- **`fzf-key-bindings.bash`**, loaded via a `-C` callback rather than a
  plain `ble-import`, specifically so it loads *after* `ble-attach` has
  already imported atuin's Ctrl-R binding — `-d` imports are deferred to
  idle time, which lands after everything in `.bashrc`. fzf's Ctrl-T/Alt-C
  survive; fzf's Ctrl-R is deliberately rebound back to atuin via two
  `ble-bind -x` calls in the same `-C` callback (rebinding rather than
  unbinding, because a ble.sh keymap with no entry for a key does nothing,
  not "fall through to atuin").

## Open bug: spurious `read: `': not a valid identifier` on Tab / auto-complete

Seen on `nire-cube`'s real terminal (VSCode's integrated terminal) as a
stray `bash: read: `': not a valid identifier` line printed alongside an
otherwise-correct completion menu, on both explicit Tab and ble.sh's
inline auto-complete-as-you-type. Diagnosed 2026-08-22 by actually
reproducing it — not just reading source — with a scripted pty (Python's
`pty` module driving a real interactive `bash -i`), per this repo's own
"evaluating proves nothing, force a real run" convention
([CLAUDE.md](../../../CLAUDE.md), [history.md](../../history.md) §25).

Findings:

- **Reproduces in a minimal config**: `ble.sh --attach=none` plus
  `source <(carapace _carapace bash)` and nothing else. No bash-completion,
  no fzf integrations, no atuin.
- **Not caused by this repo's own `carapace-desc.bash`** — stripping that
  file (and the rest of the `.blerc`) out of the test config entirely did
  not make the bug go away. Its own header invites suspicion ("checked...
  but not yet against the live menu"), but it's exonerated here: the advice
  hook it installs isn't even loaded when the bug fires.
- **Traced as far as**: ble.sh globally overrides the `read` builtin
  (`function read` in `ble.sh`, around line 27992), routing every `read`
  call through `ble/builtin/read` → `ble/bash/read`. When ble.sh calls into
  carapace's registered `_carapace_completer` via its own progcomp
  integration (`ble/complete/progcomp/.compgen-helper-func` in
  `lib/core-complete.sh`), every `read` inside that completer — including
  carapace's own `IFS=$'\001' read -r -d '' nospace data <<<"${data}"` and
  its `jobs | while read -r line` — goes through that override machinery.
- **Not pinned further than that.** Every static call site walked
  (`ble/builtin/read/.read-arguments`, `.process-option`, `ble/bash/read`)
  reconstructs `nospace`/`data` as literal, always-valid identifiers on
  paper — none of them explain an empty name at runtime. Advising
  `ble/builtin/read/.impl` directly (ble.sh's own advice framework, the
  same mechanism `carapace-desc.bash` uses) to log arguments made things
  *worse* in a different way — it broke ble.sh's own read machinery rather
  than cleanly observing it — so that avenue wasn't pushed further against
  a real interactive shell.
- **Cosmetic, not functional**: the completion menu, descriptions included,
  renders correctly on the same keypress as the stray error line.

Read as: an upstream ble.sh↔carapace progcomp interaction, present before
today's config changes and not a regression from them. Not yet filed
upstream or worked around. If it becomes annoying enough to fix rather than
ignore, the mitigation path is avoiding bash's native `complete -F`
protocol for carapace's commands (a non-progcomp carapace completion mode,
if one exists) rather than chasing the exact line inside ble.sh — see
[open-threads.md](../../open-threads.md).

## See also

- [carapace](carapace.md) — the completion engine underneath most of this,
  its generated bash completer's internals, and its `cod`-clobbering
  registration race.
- [shell-config](README.md) — the category this all lives
  in, and the `home.file`/`home.sessionPath` concatenation trap that
  `blesh.nix`'s own header is the worked example of.
- [open-threads.md](../../open-threads.md) — where unresolved upstream
  findings like the bug above are tracked.
