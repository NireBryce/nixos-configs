# carapace

A completion engine used as the primary source of shell completions across
this repo: `pkgs.carapace` in `home.packages`
([`carapace-completions.nix`](../../../flake/modules/nirePackages/shell-apps/completions/carapace-completions.nix)),
sourced into bash via `source <(carapace _carapace bash)` in `bash.nix`, and
layered under ble.sh's own menu in
[`blesh.nix`](../../../flake/modules/nire/shell-config/bash/blesh.nix) /
[`carapace-desc.bash`](../../../flake/modules/nire/shell-config/bash/carapace-desc.bash)
(see [blesh.md](blesh.md)). Unlike `cod` (below), carapace has no daemon and
no system-wide state: it's a binary invoked synchronously per completion
request, which is why it lives in `home.packages` rather than needing a
system install.

## The generated bash completer, read from its own output

`carapace _carapace bash` prints a self-contained completion script rather
than shipping one as a file — read it directly with `carapace _carapace
bash` on any host that has the binary if this ever needs re-checking; it
regenerates from carapace's own version, not from anything in this repo.
As of 2026-08-22 it does, in order:

1. Defines `get-env`/`set-env`/`unset-env` shims (`${!1}` indirect
   expansion, `export "$1=$2"`, `unset "$1"`) — carapace's generic
   shell-integration surface, not bash-specific.
2. Defines `_carapace_completer`, the function actually registered for
   completion. On each call it exports `COMP_LINE`/`COMP_POINT`/
   `COMP_TYPE`/`COMP_WORDBREAKS` and a handful of `CARAPACE_SHELL_*`
   variables carapace uses to see into the calling shell's state —
   `CARAPACE_SHELL_ALIASES`/`_BUILTINS`/`_FUNCTIONS`/`_VARIABLES` via
   `compgen -a`/`-b`/`-A function`/`-v`, and `CARAPACE_SHELL_JOBS` via `jobs
   | while read -r line; do [[ $line =~ \[([0-9]+)\] ]] && echo
   "%${BASH_REMATCH[1]}"; done` (job-table entries reformatted as `%N`
   job-spec strings).
3. Builds `compline` (the command line up to the cursor) and calls
   `carapace "$command" bash` on it with a quote character appended —
   trying `''` (empty, i.e. unquoted) first, then `'`, then `"` if the
   previous attempt exits `1` — to let carapace figure out what quoting
   context the cursor is actually in.
4. Parses the result over a `\x01`-delimited protocol:
   `IFS=$'\001' read -r -d '' nospace data <<<"${data}"` splits a leading
   nospace flag off the front of the payload; `mapfile -t COMPREPLY < <(echo
   "${data}")` then loads the actual candidates, and `unset COMPREPLY[-1]`
   drops a trailing sentinel element the encoding leaves behind. (This
   `read` call, and the one in step 2's `jobs` loop, are exactly the ones
   implicated in the ble.sh interaction bug — see
   [blesh.md](blesh.md#open-bug-spurious-read--not-a-valid-identifier-on-tab--auto-complete).)
5. Registers with `complete -o noquote -F _carapace_completer` against a
   single hardcoded list of command names — several hundred, covering
   everything from `git`/`docker`/`kubectl` to `dd`/`chmod`/coreutils.
   **Bash's own completion protocol has no description slot** — `COMPREPLY`
   is plain candidate words only, confirmed by reading this generated
   function directly rather than assuming — which is exactly the gap
   `carapace-desc.bash` exists to paper over by pulling descriptions from a
   separate `carapace <cmd> export -- <words...>` JSON mode instead (see
   [blesh.md](blesh.md)).

## The `cod` registration race, and how it's resolved

`cod` ([`cod-completions.nix`](../../../flake/modules/nirePackages/shell-apps/completions/cod-completions.nix))
is a *different* completion mechanism — a daemon that learns completions at
runtime by watching for a command's `--help` invocation, needs a system
install (hence `environment.systemPackages`, not `home.packages`), and was
carried over from before carapace existed here. Both ultimately register
through the same bash mechanism, `complete -F <function> <command>`, which
is **last-registration-wins per command name** — whichever of the two
registers last for `git` is the one that runs.

This collided in the open on 2026-08-22: cod's `PROMPT_COMMAND` hook
re-registers a command's completer every time it observes that command's
`--help` being run, silently clobbering whatever carapace had already set
up for the same name (confirmed overlap at the time included `eza`, `git`,
`nix`, `podman`, `systemctl`, `journalctl`, `cut`). cod was removed outright
for a few hours over this, then restored the same day with the actual fix:
`cod-completions.nix` generates `~/.config/cod/config.toml` at *build time*
— `carapace --list | jq` turned into one `policy = "ignore"` rule per
executable carapace already covers — so cod never tries to re-learn those
commands in the first place. The generator runs `carapace --list` inside
the Nix build sandbox (confirmed to need neither `$HOME` nor network access
to do so), so the ignore list tracks carapace's actual coverage (on the
order of a thousand commands as of 2026-08-22, still growing) automatically
rather than needing hand-maintenance every time carapace adds one.

The ignore rule is a belt-and-suspenders measure, not what wins the
*initial* race: `bash.nix`/`zsh.nix` source carapace's own bulk
registration *after* cod's `cod init` runs, so carapace's `complete -F`
calls naturally overwrite cod's for every command both know, at every shell
startup, regardless of what's already sitting in cod's local
`~/.local/share/cod/db.sqlite3` from a previous session. The ignore list
only has to stop cod from winning that race *again*, later in the same
session, the next time you happen to run `<carapace-covered-command>
--help` and cod's hook fires.

## See also

- [blesh](blesh.md) — how ble.sh layers a description column and an fzf
  menu on top of carapace's plain-word completions, and the open upstream
  bug found in that interaction.
- [shell-config](README.md) — the category `bash.nix` (the
  sourcing side) lives in.
- [`carapace-completions.nix`](../../../flake/modules/nirePackages/shell-apps/completions/carapace-completions.nix)
  and [`cod-completions.nix`](../../../flake/modules/nirePackages/shell-apps/completions/cod-completions.nix)
  — the modules themselves, with the fuller history in their own comments.
