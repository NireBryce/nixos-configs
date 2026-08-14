# Handoff: nire-durandal and nire-lysithea

> **Written by Claude Code, for Claude Code**, from `nire-tenacity` after taking
> this branch from "evaluates" to "runs" on it. `CLAUDE.md` has the rules and
> `claude cave/lessons-learned.md` has the mistakes; this is only what is specific to
> **nire-durandal** (workstation, x86_64-linux) and **nire-lysithea**
> (M3 MacBook Air, aarch64-darwin).

Tenacity is the testbed. It booted 2026-08-10 and has been through six
generations of fixes since. Everything below is what that bought the other two.

---

# nire-durandal — workstation

Already a full host: `nireHost/durandal-configuration.nix` lists its imports and
`nireHost/durandal/` holds its five modules. It has **never been built or
switched on this branch**, which is deliberate for now rather than a backlog
item.

## Free, because it is in shared categories

Every tenacity fix lives in a category durandal already imports, so it arrives
the moment durandal is built: systemd stage 1 and the `restore-root` unit,
`nohibernate` plus the KDE `SleepMode` counterpart, VS Code out of
`programs.vscode`, blesh ordering, Ctrl-R to atuin, flatpak-repo's network
guard, the coredump cap.

**None of it is verified there.** Every one was checked on tenacity only. Say
which host you mean.

## durandal-only, and unexercised

| | |
|---|---|
| `boot-durandal.nix` | `sbctl`, and `efi.canTouchEfiVariables = true` — tenacity sets neither |
| `b550-suspend-fix.nix` | motherboard-specific; no handheld equivalent |
| `hardware-configuration.nix` | has a `/var/lib/sbctl` filesystem tenacity lacks |
| `stateVersion` | **23.11**, against tenacity's 25.05 |

Secure boot is the one to be careful with: `sbctl` plus
`canTouchEfiVariables = true` means a switch can write EFI variables, which is
the one thing here that can break a boot in a way picking an older generation
does not fix. Nothing on this branch has exercised it.

## Genuinely unanswered

- **`just hm-collisions` has never been run there.** Tenacity came back clean —
  42 of 57 files already Home-Manager-owned — which says nothing about
  durandal's `$HOME`. It is read-only; run it first.
- Whether the `/root` rollback works. durandal imports `impermanence` too (was
  `boot`, renamed 2026-08-11), so it wipes `/root` and needs a `root-blank`
  subvolume. Confirm that exists *before* switching.

## The order that worked

1. `sudo just baseline > ~/baseline-preswitch.md` — toplevel, kernel command
   line, declarative users, mounts, subvolumes. **Unrecoverable once the new
   generation boots and the store is collected.**
2. `just hm-collisions` — expect "No collisions. This is a relink."
3. Pin the standalone Home Manager profile:
   ```sh
   nix-store --add-root ~/hm-pre-cutover --indirect -r \
     "$(readlink -f ~/.local/state/nix/profiles/home-manager)"
   ```
   Switching to integrated HM runs `nixProfileRemove home-manager-path`, and
   that profile lives in `$HOME`, not the system generation — so **a system
   rollback does not restore it**, and `nix-collect-garbage -d` prunes the
   generation links that are the only other way back. This cost a generation on
   tenacity.
4. `just build`, then `just diff-deployed` — the package diff says what a
   drvPath cannot.
5. `just boot`, then reboot deliberately. Prefer `boot` over `switch` for
   anything touching initrd, the bootloader or impermanence.
6. Confirm the rollback *ran*, not that the machine came up: the `/root`
   subvolid must change across the reboot. Tenacity went 607 → 622 → 627 → 652
   while its neighbours sat at 257–265.

---

# nire-lysithea — M3 MacBook Air

**This host does not exist in the config.** No `darwinConfigurations` output, no
nix-darwin input, no host directory. Greenfield, and the tree is less ready than
it looks.

## What is actually there for darwin

One module, holding three fonts:

```
nireUser/elly/user-settings/elly-user.nix
    flake.modules.darwin.elly-user = { fonts.packages = [ … ]; }
```

Every `dirsAsCategory.nix` also declares
`flake.modules.darwin.<category>.imports`, so a darwin aggregate exists for
every category — but they collect only modules that declare a darwin class, and
apart from those fonts, none do. **They are empty.** Importing one is harmless
and gets you nothing.

## Two ways in

**Standalone Home Manager, no nix-darwin.** The 101 homeManager modules are
where the value is — shell config, dotfiles, most packages. This gets them onto
the laptop without adopting nix-darwin, and
`flake/doc/trailhead-home-manager-standalone.md` already documents the
`homeConfigurations` mechanics, because reversing tenacity's integration needs
the same output.

**nix-darwin with `darwinConfigurations`.** Buys system-level settings, costs a
new input plus darwin-class modules that mostly do not exist. Worth it only if
system settings are the point.

Start with the first. Smaller, half-documented already, and it fails in a home
directory rather than at boot.

## Hazards specific to this

- **Never import the `impermanence` category** (was `boot` until 2026-08-11).
  It is `WARN-impermanence`, which deletes the `/root` btrfs subvolume in
  initrd. It is nixos-class so it cannot apply to darwin — but do not let it
  near a shared aggregate either.
- **Not every homeManager module is portable.** They are named by function, not
  platform: `nirePackages/linux-utils/` is obvious, but Linux-only packages are
  scattered elsewhere too. Expect evaluation failures on the first attempt and
  treat that as filtering, not a bug.
- **`useGlobalPkgs` does not exist standalone.** The NixOS integration is what
  makes HM reject `nixpkgs.*` options; standalone needs `pkgs` configured
  itself, including `allowUnfree`, which currently comes from the system side of
  `basic-nix-settings.nix`.
- **`elly` is hardcoded** in `users.users.elly`, `home.username` and
  `home-manager.users.elly`.
- **`checks.nix` filters hosts by system**, so `checks.aarch64-darwin` holds only
  `module-tree` — which is static and passes without proving anything builds.
  Adding a darwin host does not automatically get it a meaningful check.

## The thing that will bite

Most of this repo was written *from* an aarch64-darwin laptop against
x86_64-linux hosts with no remote builder, which is why so much of it says
"verified" meaning *evaluates*. Working on lysithea puts you back in that
position for anything Linux-shaped — except that now the laptop is the target
rather than the workstation. Say which rung you mean: `lessons.md` §18 and §25.

---

# What cost the most on tenacity

All in `lessons.md` with the detail:

- **The repo is not the machine** (§2, §24). `swapDevices = [ ]` while 20G of
  swap was active, and a guard written on that basis could never fire.
- **Running it finds a different class than building it** (§25). Four defects
  appeared at first boot that evaluation and a successful build both missed.
- **"Did it work before?" is one command** (§26). `journalctl --list-boots` plus
  a grep settled three questions I had reasoned about at length and got wrong.
- **The shell's view of the machine is a mount namespace** (§19). `lsblk`,
  `findmnt` and `/etc` all describe the sandbox. Use `/proc/1/mountinfo`,
  `/dev/disk/by-uuid/` and store paths.
- **Check upstream before writing a patch** (§27).
