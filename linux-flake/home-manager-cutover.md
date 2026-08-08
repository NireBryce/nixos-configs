# Home Manager cutover — the first switch

Home Manager is applied as part of the system now, not via a separate
`nh home switch`. This covers the first switch on durandal, which is the only
step where anything can go wrong.

Adapted from the same document on the sibling `flake-parts` branch, which was
read out of the pinned Home Manager source (`modules/home-environment.nix`,
`modules/files/check-link-targets.sh`, `nixos/common.nix`). The mechanism is
identical; what differs here is the starting state, which is worse — see below.

## What changes

| | before | after |
|---|---|---|
| applied by | nothing — see below | `nh os switch` / `just switch` |
| `home.profileDirectory` | `~/.nix-profile` | `/etc/profiles/per-user/elly` |
| packages installed via | `nix profile install` into the user profile | `users.users.elly.packages` |
| activation runs as | you, from the CLI | `home-manager-elly.service` during system activation |

`users.users.elly.packages` is now the six emergency packages from
`nireUser/elly/user-settings/elly-user.nix` plus `home-manager-path`, which is
the 128-package HM closure.

## Read this before switching: the starting state is unknown

The sibling branch could say "durandal's dotfiles are already HM-owned symlinks,
so collisions are unlikely". **That claim does not transfer here**, and it is the
one thing worth being careful about.

This branch produced `flake.homeConfigurations.elly-nire-durandal` under den, but
the branch has not evaluated since March, so nothing on it has ever been applied.
Whatever is on durandal now was put there by some earlier config, and this
document cannot tell you which. Before switching, look:

```sh
readlink -f ~/.zshrc ~/.bashrc ~/.gitconfig    # into /nix/store => HM-owned already
nix profile list | grep home-manager-path      # present => a standalone HM profile exists
ls ~/.local/state/nix/profiles/ 2>/dev/null    # old HM generations
```

If those are store symlinks, this is a relink and low risk. If they are real
files, every one of them is a collision (see below).

## The good news: an old standalone profile cleans itself up

Home Manager handles this migration explicitly. With `useUserPackages = true`,
its `installPackages` activation step reduces to exactly one command:

```
nixProfileRemove home-manager-path
```

with the upstream comment "In case the user has moved from a user-install of Home
Manager to a submodule managed one we attempt to uninstall the
`home-manager-path` package if it is installed."

So **you do not need to expire the old profile by hand.** Old *generations* under
`~/.local/state/nix/profiles/` linger as GC roots; they are harmless and go away
on the next `nix-collect-garbage -d`.

## The one real risk: file collisions

Home Manager refuses to overwrite a file it does not already own.
`check-link-targets.sh` collects them and aborts with:

```
Existing file '<path>' would be clobbered
```

Everything this config manages is a candidate: `~/.zshrc`, `~/.zshenv`,
`~/.bashrc`, `~/.blerc`, `~/.gitconfig`, `~/.config/F-Sy-H`, `~/.justfile`,
`~/.dir_colors`, and the rest. `just dotfiles` lists them all.

If activation aborts that way, set the escape hatch in
`modules/nire/system/home-manager/enable-home-manager.nix`:

```nix
home-manager.backupFileExtension = "hm-bak";
```

which moves each conflicting file aside instead of erroring. Switch, confirm you
did not want anything in the `*.hm-bak` files, then **remove the option again** so
future collisions stay loud. There is also `overwriteBackup` and `backupCommand`
if you would rather not accumulate backups.

## Procedure

```sh
just check      # evaluates everything; on darwin this only runs the module-tree check
just build      # nh os build, no activation -- catches eval and build errors
just switch     # nh os switch
```

`just build` and `just switch` are Linux-only. `just check` builds the host and
home derivations on Linux; on the mac `checks.aarch64-darwin` contains only
`module-tree`, so it exercises almost nothing.

## Verifying it took

```sh
systemctl status home-manager-elly.service     # active (exited)
ls /etc/profiles/per-user/elly/bin | wc -l     # the HM closure, not ~/.nix-profile
nix profile list | grep home-manager-path      # should print nothing
readlink -f ~/.zshrc                           # should point into /nix/store
```

`journalctl -u home-manager-elly.service -b` has the activation log.

## Rolling back

Home Manager is part of the system generation, so a system rollback takes home
with it — there is no separate HM rollback:

```sh
nixos-rebuild switch --rollback     # or pick the previous generation at boot
```

If you backed files out with `backupFileExtension`, rolling back does **not**
restore them; move the `*.hm-bak` files back by hand.

## Gotchas

- **`nh home switch` no longer does anything here.** There is no
  `homeConfigurations` output at all. Stale shell history or aliases reaching for
  it will fail confusingly.
- **`useGlobalPkgs` means HM rejects `nixpkgs.*` options** — errors, not ignores.
  That is why `basic-nix-settings.nix` lost its homeManager `nixpkgs.config`.
  `allowUnfree` comes from the system side of that same file now, but the
  `allowUnfreePredicate` workaround for HM issue #2942 is gone. If unfree
  packages start failing, that is why.
- **Activation runs as a systemd unit, not your shell.** Anything assuming a
  login environment — `$PATH` from your shell, an ssh-agent, a running gpg-agent
  — will not see it. The unit's `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd, and `QT_QPA_PLATFORM=offscreen`.
- **Impermanence is live on this host.** `WARN-impermanence.nix` deletes the
  `/root` btrfs subvolume in initrd on every boot. It is unrelated to the HM
  cutover, but the first reboot after a switch is when you would find out
  something about it was wrong, so it is worth a look first.
- **Nothing in this repo has ever been built or switched.** This procedure is
  derived from the config and from Home Manager's source, not from having run it.

## Going the other way

`home-manager-standalone.md` covers reverting to standalone, including the part
of that which is one-way on the machine rather than in the repo.
