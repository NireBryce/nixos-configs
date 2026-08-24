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

## Bug: spurious `read: `': not a valid identifier` on Tab / auto-complete

Seen on `nire-cube`'s real terminal (VSCode's integrated terminal) as a
stray `bash: read: `': not a valid identifier` line printed alongside an
otherwise-correct completion menu, on both explicit Tab and ble.sh's
inline auto-complete-as-you-type. First diagnosed 2026-08-22 by actually
reproducing it — not just reading source — with a scripted pty (Python's
`pty` module driving a real interactive `bash -i`), per this repo's own
"evaluating proves nothing, force a real run" convention
([CLAUDE.md](../../../CLAUDE.md), [history.md](../../history.md) §25); that
session pinned the bug as far as "somewhere inside ble.sh's global `read`
override" but no further (see history below). Reopened 2026-08-24 when it
was reported by a user typing over SSH — reproduced again with the same pty
technique, packaged that same day as a reusable tool
(`flake/scripts/ssh-pty-drive.py` at the time, since generalized beyond SSH
and moved out to its own repo,
[`terminal-puppeteer`](https://github.com/NireBryce/terminal-puppeteer) —
not part of this repo any more, kept here only as the "how this was found"
credit),
and pinned the rest of the way to a specific line and a working fix. Full
session account: [lessons-learned.md](../../../claude%20cave/lessons-learned.md) §39.

**Root cause**: ble.sh's own auto-complete/progcomp machinery installs a
cancellation safety net, `_ble_builtin_read_hook`, while any registered
completer is running — checked every `bleopt_complete_polling_cycle` reads
(50 by default) against whether the user is still typing
(`ble/complete/progcomp/.check-limits`, `lib/core-complete.sh`). That check
succeeding during ordinary fast typing is the *common* case, not an edge
case. When it succeeds mid-completer, the hook redirects whatever `read`
call was in flight through a fallback path
(`ble/bash/read "$@" < /dev/null; return 148`) — and when the read call
caught by that fallback is carapace's own read line (see
[carapace.md](carapace.md) for what it actually is — its visible `IFS=''`
is an invisible SOH byte, not a literally empty string, confirmed with
`od -c` after that misreading briefly derailed this diagnosis too), the
forwarded `"$@"` comes back split character-by-character instead of into
the two variable names, which is exactly what produces the
empty-identifier error.

**Not caused by this repo's own `carapace-desc.bash`** — confirmed twice,
independently, two days apart: stripping the whole `.blerc` out of a
minimal test config didn't stop it (2026-08-22), and neither did removing
just the advice from a live shell and re-sourcing carapace's stock
completer plain (2026-08-24). It's a genuine carapace↔ble.sh interaction,
exposed by this repo routing carapace through bash's native `complete -F`
protocol for the first time, not introduced by anything layered on top of
it.

**Fix, in the tree as of 2026-08-24, not yet switched**: don't call `read`
for that line at all, so there's nothing for ble.sh's global override to
catch —
[`carapace-completer-read-fix.bash`](../../../flake/modules/nire/shell-config/bash/carapace-completer-read-fix.bash)
(see
[`carapace-read-fix.md`](../../../flake/modules/nire/shell-config/bash/carapace-read-fix.md)
next to it for the operator-facing summary and how to undo it)
patches `_carapace_completer`'s body via `declare -f` plus a textual
substitution, replacing the `read` with parameter expansion split on the
same real SOH byte (`nospace=${data##*$sep}; data=${data%$sep*}`), sourced
from `bash.nix` right after `source <(carapace _carapace bash)` and before
`carapace-desc.bash`'s advice wraps the same function. Validated three
ways: the substitution reproduces the exact byte checked with `od -c`
against carapace's real output; applied by hand to the real
`_carapace_completer` on `nire-cube` via the pty-driving tool mentioned
above and driven through four different Tab-completions with zero errors,
where each
reliably errored before; and `just modules` clean with the change
evaluating correctly into `programs.bash.initExtra`. **Not yet run through
an actual `just switch`** — the live validation patched an already-running
shell by hand, not a rebuilt-and-switched host — see
[open-threads.md](../../open-threads.md) and lessons-learned.md §39 before
assuming that step is done. Tracked as
[issue #72](https://github.com/NireBryce/nixos-configs/issues/72); update
that, not just this page, once `just switch` confirms it.

Still worth filing upstream — this repo's fix is a local workaround, not a
change to carapace or ble.sh — but low priority now that it no longer
produces wrong output, only (until switched) the cosmetic stray line. Not
filed, and not something to file on the strength of this page alone: per
`CLAUDE.md`, filing against either project needs Elly to say so explicitly
first.

## See also

- [carapace](carapace.md) — the completion engine underneath most of this,
  its generated bash completer's internals, and its `cod`-clobbering
  registration race.
- [shell-config](README.md) — the category this all lives
  in, and the `home.file`/`home.sessionPath` concatenation trap that
  `blesh.nix`'s own header is the worked example of.
- [open-threads.md](../../open-threads.md) — where unresolved upstream
  findings like the bug above are tracked.
