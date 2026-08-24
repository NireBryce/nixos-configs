# nix-darwin: `homebrew.onActivation.cleanup` requires Homebrew ≥ 6.0, with no version check and no error naming the requirement

Written 2026-08-13 against nix-darwin
`15abb8c98f336cd8bd840d71059adebabe60bf04` (current `master` HEAD at time of
writing, and the rev pinned in the affected config), Homebrew 5.1.6, macOS on
aarch64.

Paste-ready for <https://github.com/nix-darwin/nix-darwin/issues>. Everything
below the "Describe the bug" heading is the report; the last section is local
notes and should be dropped before filing.

**Not filed. Not to be filed on the strength of this file existing** — per
`CLAUDE.md`, filing outside `NireBryce/nixos-configs` needs Elly saying so
explicitly, in those words, for this specific report.

---

## Describe the bug

Since #1789, the Homebrew module emits `--force-cleanup` when
`homebrew.onActivation.cleanup` is `"uninstall"` or `"zap"`. That switch was
introduced in **Homebrew 6.0.0** (2026-06-11). On any Homebrew 5.x it does not
exist, so `brew` rejects it and system activation aborts:

```
Homebrew bundle...
Usage: brew bundle [subcommand]
...
Error: invalid option: --force-cleanup
```

The module has no version detection and no assertion, so the only thing that
tells you nix-darwin now requires Homebrew 6 is `brew`'s own argument parser
failing mid-activation on a flag the user never wrote.

This is not "a flag was removed". It is a hard version floor that was raised
silently. There is no overlap between the two Homebrew generations here:

| flag emitted | Homebrew < 6.0 | Homebrew ≥ 6.0 |
| --- | --- | --- |
| `--force-cleanup` (current) | `Error: invalid option` | works |
| `--cleanup` (pre-#1789) | works | `UsageError`, and deprecated |

So no single flag string satisfies both, and the module currently picks one
without checking which one applies.

## Steps to reproduce

On a machine whose Homebrew is 5.x (`brew --version`), with any nix-darwin at
or after #1789:

```nix
{
  homebrew.enable = true;
  homebrew.onActivation.cleanup = "uninstall";   # or "zap"
  homebrew.casks = [ "firefox" ];
}
```

```console
$ darwin-rebuild switch --flake .
...
Homebrew bundle...
Error: invalid option: --force-cleanup
```

The generated command can be inspected without switching:

```console
$ nix eval --raw \
    '.#darwinConfigurations.<host>.config.homebrew.onActivation.brewBundleCmd' \
    --apply 'f: f { onlyCheck = false; }'
PATH="/opt/homebrew/bin:/nix/store/…-mas-7.0.0/bin:$PATH" sudo --preserve-env=PATH \
  --user=… --set-home env HOMEBREW_NO_AUTO_UPDATE=1 \
  brew bundle --file='/nix/store/…-Brewfile' --no-upgrade --force-cleanup
```

## Expected behaviour

One of:

- the module detects the installed Homebrew version at activation and emits the
  flags that version understands; or
- if Homebrew 6.0 is now the supported floor, activation fails with a message
  that says so — "homebrew.onActivation.cleanup requires Homebrew 6.0 or newer;
  found 5.1.6, run `brew update`" — rather than surfacing `brew`'s
  `invalid option` for a flag the user did not write.

Either way the option's own documentation should describe the flags actually
emitted.

## Root cause

`modules/homebrew.nix`, in `brewBundleCmd` (lines 193–199 at the rev above):

```nix
if onlyCheck then
  [ "cleanup 2>&1" ]
else
  optional (!config.upgrade) "--no-upgrade"
  ++ optional (config.cleanup == "uninstall") "--force-cleanup"
  ++ optional (config.cleanup == "zap") "--zap --force-cleanup"
  ++ config.extraFlags
```

Introduced by #1789 ("homebrew: address new CLI flag requirements", merged
2026-06-17), which closed #1787. The change itself is correct **for Homebrew
6**; it is applied unconditionally.

The Homebrew side, `Library/Homebrew/bundle/subcommand/install.rb` at 6.0.0
through 6.0.17:

```ruby
switch "--cleanup",
       description: "Ask to perform cleanup after installing dependencies. Requires `--force`, " \
                    "`--force-cleanup` or `$HOMEBREW_ASK`.",
       env:         [:bundle_install_cleanup, "--global"],
       odeprecated: true
switch "--force-cleanup",
       description: "Perform cleanup after installing dependencies without asking.",
       env:         [:bundle_force_install_cleanup, "--global"]
```

and, in `run`:

```ruby
if args.cleanup? && !context.force && !args.force_cleanup? && !context.ask
  raise UsageError, "`brew bundle install --cleanup` requires `--force`, `--force-cleanup` " \
                    "or `$HOMEBREW_ASK`."
end
```

Before 6.0.0, `brew bundle`'s flags lived in `Library/Homebrew/cmd/bundle.rb`,
which declares `-f`/`--force` and `--cleanup` and has no `--force-cleanup` at
all. Checked at tags 5.1.6, 5.1.0, 5.0.0 and 4.6.0 — `--force-cleanup` appears
in none of them. There is no 5.2.x, so 5.1.6 is the last release before the
break.

In 5.x, `--cleanup`'s own description is "`install` performs cleanup operation,
same as running `cleanup --force`" — i.e. the pre-#1789 nix-darwin behaviour was
exactly what the `"uninstall"` enum value promises, on that generation.

Two secondary points in the same area:

- **The option docs were not updated by #1789.** `homebrew.onActivation.cleanup`
  still documents (homebrew.nix:98, 103) that `"uninstall"` invokes
  `brew bundle [install]` "with the `--cleanup` flag" and `"zap"` with
  "`--cleanup --zap`". Neither is what the module emits any more. The generated
  option reference therefore describes the Homebrew 5 behaviour while the code
  requires Homebrew 6.
- **The module already knows about the 6.0 dependency elsewhere.** #1789 also
  added `trusted` options whose descriptions explicitly say "Homebrew 6.0.0
  enabled `HOMEBREW_REQUIRE_TAP_TRUST` by default" (homebrew.nix:298, 554, 624).
  So the same PR documented a Homebrew 6 requirement for taps and left the
  cleanup requirement undocumented and unguarded.

## Why this is likely to be hit rather than self-correcting

`onActivation.autoUpdate` defaults to `false`, and the activation command sets
`HOMEBREW_NO_AUTO_UPDATE=1` whenever it is false. A nix-darwin-managed Homebrew
therefore does not update itself during activation, by design and by default. A
machine that installed Homebrew before 2026-06-11 and has only ever been driven
by `darwin-rebuild` will still be on 5.x, and will stay there — so "just update
Homebrew" is the fix, but nothing in the normal nix-darwin workflow performs it
or suggests it.

## Suggested fix

Prefer version detection, since the activation script is shell and `brew` is
already on `PATH` there:

```
if brew bundle install --help 2>/dev/null | grep -q -- --force-cleanup; then
  cleanup_flag=--force-cleanup
else
  cleanup_flag=--cleanup
fi
```

Capability detection rather than version parsing avoids guessing at where in the
6.0 pre-release series the switch appeared.

Failing that, `--cleanup --force` is accepted by both generations — but it is
**not** a drop-in equivalent and I would not recommend it as the fix. `--force`
is also threaded into the install path (`Installer.install!(… force: context.force …)`),
so it turns every activation into `brew install --force`/`--overwrite`, and on
6.x `--cleanup` is `odeprecated: true`, so it warns on every switch.

Whichever route is taken, the `cleanup` option's description needs updating to
match, and a supported-Homebrew-version note would be worth adding to the module
header.

## Workaround

Set `cleanup = "none"` and pass the flag the installed Homebrew understands:

```nix
homebrew.onActivation.cleanup    = "none";
homebrew.onActivation.extraFlags = [ "--cleanup" ];       # Homebrew 5.x only
```

`extraFlags` is appended after the `cleanup` optionals, so with `cleanup =
"none"` nothing conflicts. **This inverts the bug rather than fixing it** — the
moment Homebrew reaches 6.x, bare `--cleanup` starts raising
`UsageError: brew bundle install --cleanup requires --force, --force-cleanup or
$HOMEBREW_ASK`, and activation breaks again in the other direction.

The durable answer for a user hitting this is `brew update` to 6.x and then
plain `cleanup = "uninstall"`.

## Additional context

- #1807 is the same error, reported 2026-06 and closed as a duplicate of #1787.
  It should probably be reopened, or this treated as its successor: after it was
  closed, the reporter corrected themselves — *"I was too quick to resolve this
  issue - my issue was that my system still used Brew 5.x but nix-darwin was
  trying to use the new Brew 6.x cli syntax."* That comment is the actual bug and
  it arrived after the thread had stopped being read. No open issue covers it.
- #1802 ("homebrew: use --force-cleanup for bundle activation") was closed
  unmerged, having been superseded by #1789. Its description is worth reading for
  the Homebrew 6 deprecation-warning behaviour of bare `--cleanup`.
- `--force-cleanup` also reads `HOMEBREW_BUNDLE_FORCE_INSTALL_CLEANUP`. The
  `env:` value is declared as `[:bundle_force_install_cleanup, "--global"]`, but
  `Library/Homebrew/cli/parser.rb` destructures that as `env, counterpart = env`
  and uses the second element only to build the help text — so the variable takes
  effect regardless of `--global`, despite the generated description saying "and
  `--global` is passed". That makes the env var usable through
  `onActivation.extraEnv` on 6.x, though it is a no-op on 5.x and so does not
  help here.
- The `"check"` path is unaffected: it emits the `brew bundle … cleanup`
  *subcommand*, not the install-time switch, and that spelling is stable across
  both generations.

---

## Local notes — remove before filing

Found on `nire-lysithea` (aarch64-darwin), written up from `nire-durandal`.
Recorded in this repo at
`flake/modules/nire/macos/homebrew/homebrew.nix`, which carries the
workaround and a comment about it.

**That comment is wrong about the cause and should be corrected.** It says
Homebrew "removed" `--force-cleanup` and that nix-darwin is "not fixed
upstream". Both readings are backwards:

- `--force-cleanup` was never in Homebrew 5.x to be removed. It was *added* in
  6.0.0. The comment's own evidence is sound — it checked
  `/opt/homebrew/Library/Homebrew/cmd/bundle.rb` and correctly found `--cleanup`
  and `--force` and no `--force-cleanup` — but that file is the 5.x parser, and
  on 6.x the flags moved to `Library/Homebrew/bundle/subcommand/install.rb`. The
  absence was read as a removal when it was a version skew.
- Upstream considers this fixed (#1789), for Homebrew 6. nix-darwin `master`
  resolving to the same rev as the pin is true — I confirmed `master` HEAD is
  `15abb8c98f336cd8bd840d71059adebabe60bf04`, the pinned rev — but it means
  "nothing has changed since", not "upstream is sitting on a known break".
- The comment's plan, "revisit when the input moves — if `cleanup` starts
  working, this pair should collapse back to it", has the trigger inverted. The
  input moving will not fix it; **updating Homebrew on lysithea will**, and at
  that moment the current workaround becomes the thing that breaks activation.

Unverified from here, worth doing on lysithea before filing:

- `brew --version` — 5.1.6 is what the module comment records, and the whole
  report is pinned to that. Confirm it, and confirm the machine has not been
  updated since.
- Whether `brew update && brew upgrade` to 6.0.x, followed by dropping the
  workaround for plain `cleanup = "uninstall"`, works end to end. If it does,
  that is the real fix for this repo and the workaround should come out — but
  note that `cleanup = "uninstall"` will then actually uninstall, so `just
  hm-collisions`-style caution applies: check what `brew bundle cleanup` would
  remove before switching, since the Brewfile is the 59-cask list and anything
  hand-installed goes.
- Whether the suggested capability-detection snippet actually works inside the
  activation script's `sudo … env` invocation. It is untested; the reproduction
  in this report is by evaluation and source reading plus the observed
  `invalid option` failure, not by running a patched activation.
