# Home Manager cutover — standalone → NixOS-integrated

As of `cd520dc` (2026-08-06) Home Manager is applied as part of the system
instead of via a separate `nh home switch`. This doc covers the first switch on
each host, which is the only step where anything can go wrong.

Everything below was read out of the pinned Home Manager source
(`inputs.home-manager`, `modules/home-environment.nix`,
`modules/files/check-link-targets.sh`, `nixos/common.nix`) and out of the
evaluated durandal config, not from memory.

## What actually changes

| | before | after |
|---|---|---|
| applied by | `nh home switch --configuration elly@nire-durandal` | `nh os switch` / `just switch` |
| `home.profileDirectory` | `~/.nix-profile` (this config has `nix.useXdg = false`) | `/etc/profiles/per-user/elly` |
| packages installed via | `nix profile install` into the user profile | `users.users.elly.packages` |
| activation runs as | you, from the CLI | `home-manager-elly.service` during system activation |
| tenacity | **no home config existed at all** | same config as durandal |

`users.users.elly.packages` is now the six emergency packages from
`nire/users/elly.nix` plus `home-manager-path`, which is the 136-package HM
closure.

## The good news: the old profile cleans itself up

Home Manager explicitly handles this migration. With `useUserPackages = true`,
its `installPackages` activation step is reduced to exactly one command:

```
nixProfileRemove home-manager-path
```

with the upstream comment "In case the user has moved from a user-install of
Home Manager to a submodule managed one we attempt to uninstall the
`home-manager-path` package if it is installed."

`nixProfileRemove` looks for `~/.nix-profile/manifest.json` (or the XDG path)
and runs `nix profile remove`, falling back to `nix-env -e`. So **you do not
need to manually expire the old standalone profile** — the first integrated
activation removes `home-manager-path` from it for you.

Old *generations* under `~/.local/state/nix/profiles/` still linger as GC
roots. They're harmless; they go away on the next `nix-collect-garbage -d`.

## The one real risk: file collisions

Home Manager refuses to overwrite a file it doesn't already own.
`check-link-targets.sh` collects these and aborts with:

```
Existing file '<path>' would be clobbered
```

**This is much more likely on tenacity than on durandal.** Durandal's dotfiles
are already HM-owned symlinks, so HM recognises them as its own and relinks
them. Tenacity has never had Home Manager, so every file this config manages —
`~/.zshrc`, `~/.bashrc`, `~/.config/git/*`, the p10k config, and so on — is
whatever is sitting there now, and each one is a potential collision.

If activation aborts that way, set the escape hatch in
`modules/nire/home-manager/enable-home-manager.nix`:

```nix
home-manager.backupFileExtension = "hm-bak";
```

which moves each conflicting file aside instead of erroring. Switch, confirm
you didn't want anything in the `*.hm-bak` files, then remove the option again
so future collisions stay loud. There is also `overwriteBackup` (clobber
existing backups) and `backupCommand` (e.g. `trash-cli`) if you'd rather not
accumulate `.hm-bak` files.

## Procedure

Per host, tenacity last since it's the riskier one.

```sh
just build                  # nh os build, no activation — catches eval/build errors
just switch                 # nh os switch
```

`just check` builds both hosts' toplevels. Note this only does something on
Linux: `checks` is filtered by system, so on the mac `checks.aarch64-darwin` is
empty and `nix flake check` there only exercises the formatter.

## Verifying it took

```sh
systemctl status home-manager-elly.service         # should be active (exited)
ls /etc/profiles/per-user/elly/bin | wc -l         # the HM closure, not ~/.nix-profile
nix profile list | grep home-manager-path          # should print nothing
readlink -f ~/.zshrc                               # should point into /nix/store
```

`journalctl -u home-manager-elly.service -b` has the activation log if
something looks off.

## Rolling back

Home Manager is part of the system generation now, so the system rollback takes
home with it — there is no separate HM rollback to remember:

```sh
nixos-rebuild switch --rollback     # or pick the previous generation at boot
```

If you backed files out with `backupFileExtension`, rolling back the generation
does **not** restore them; move the `*.hm-bak` files back by hand.

## Gotchas

- `nh home switch` no longer does anything useful here. `notes-and-fixes.md`
  and the `.justfile` were updated; if you have shell history or aliases
  reaching for it, they're stale.
- `useGlobalPkgs = true` means Home Manager rejects `nixpkgs.*` options. That's
  why `elly-nix-settings` lost its `nixpkgs.config`. `allowUnfree` comes from
  the system now (`nire/nix/nix-settings`), but the `allowUnfreePredicate`
  workaround for HM issue #2942 is gone — if that resurfaces, that's why.
- Activation runs as a systemd unit, not as your interactive shell. Anything in
  the HM config that assumed a login environment (`$PATH` from your shell,
  an ssh-agent, a running gpg-agent) won't see it. The unit's `PATH` is just
  coreutils/findutils/gnugrep/gnused/systemd, and `QT_QPA_PLATFORM=offscreen`.
