# Handoff: to the instance running on nire-tenacity

From Darryl, who did the work on `flake-parts-consolidation` from Elly's darwin
laptop. Predecessors, for the naming: Alice worked the sibling `flake-parts`
branch, Bob wrote the port prompt that started this.

Delete this file once tenacity is switched and the checklist below is answered.

---

## Read these first

`CLAUDE.md` at the repo root, then whichever of these the work touches:

| | |
|---|---|
| `TENACITY-PLAN.md` | how this host was brought back, and what the plan got wrong |
| `linux-flake/home-manager-cutover.md` | the first-switch runbook — read before `just switch` |
| `linux-flake/impermanence-stage1.md` | why the root rollback works the way it does |
| `linux-flake/style-guide.md` | conventions, before writing any module |
| `linux-flake/2026-08-08 lessons.md` | how the work went wrong in the doing |

## Getting the code

**Five commits are unpushed as of writing.** Ask Elly to push, or you will be
working against a tree that stops at `41d857d`:

```
93d480d feat: tenacity gets impermanence; jovian is a handheld module, not a host's
cbfb2da fix: impermanence back to postResumeCommands, which is what actually runs
41d857d added wishlist file for later
8e89401 feat: add nire-tenacity
7a38800 fix: the collision check could not see the collision it was written for
```

Tenacity's checkout is ~11 commits behind `origin/main`, and `origin/main` is
itself **172 commits behind** `flake-parts-consolidation` — main is a strict
ancestor, nothing on it is missing here. The branch you want is
`flake-parts-consolidation`.

```sh
git fetch origin
git checkout flake-parts-consolidation
git log --oneline -1     # expect 93d480d or later
```

## Why you exist

**Nothing in this repository has ever been built or switched.** Every "verified"
claim in every doc and commit message means *evaluates and produces the expected
derivation* — never *runs*. The dev machine is aarch64-darwin; both hosts are
x86_64-linux; there is no remote builder and no binfmt. The single exception is
`checks.<system>.module-tree`, which is static.

You are on the hardware. You can build, you can look at the disk, and you can
switch. That is the entire point of you.

```sh
just check      # both hosts' toplevels + both home activations + module-tree
just build      # this host, no activation
just switch     # applies Home Manager too; there is no separate home switch
```

`just check` on darwin only ran `module-tree`; on tenacity it runs all five:
`nixos-nire-durandal`, `nixos-nire-tenacity`, `home-nire-durandal`,
`home-nire-tenacity`, `module-tree`.

## The checklist — things only this machine can answer

Work top to bottom. The first two are boot-fatal if wrong.

### 1. Does `root-blank` exist? — blocks impermanence, fails in initrd

This host now imports the `boot` category, so `/root` is deleted and recreated
on every boot from a snapshot:

```
btrfs subvolume snapshot /mnt/root-blank /mnt/root
```

If no `root-blank` subvolume exists on the btrfs top level, **the machine will
not boot**. It should exist from when this host last ran impermanence, but that
was before the restructure and nobody has checked.

```sh
sudo mkdir -p /mnt-check
sudo mount -o subvol=/ /dev/mapper/enc /mnt-check
sudo btrfs subvolume list -o /mnt-check | grep -E 'root-blank|root$'
sudo umount /mnt-check
```

If it is missing, do not switch. Creating one is a deliberate act — take a blank
`/root` snapshot at a moment you are happy to return to on every boot.

### 2. Is the hardware config still accurate?

`modules/nireHost/tenacity/hardware/hardware-tenacity.nix` is the January 2026
generator output, reused verbatim. Elly confirmed nothing about the machine has
changed, but that was from memory, on another machine.

```sh
lsblk -o NAME,UUID,FSTYPE,MOUNTPOINT
findmnt -no SOURCE,FSTYPE,OPTIONS /  /home /nix /persist /var/log /boot
cat /etc/crypttab 2>/dev/null; ls /dev/mapper/
```

Expected: LUKS volume named `enc`; btrfs subvolumes `root`, `home`, `nix`,
`persist`, `log`; root filesystem UUID `a99ae3fe-3254-4d6b-9da7-c448a89d166d`;
LUKS device UUID `03b8f5c0-d846-4fde-b533-2a22e8e9975b`; `/boot` vfat
`380C-3C39`. If any differ, regenerate rather than patch, and wrap the result as
a flake-parts module **in the same commit** — a raw `nixos-generate-config` file
under `modules/` produces `infinite recursion encountered` naming `modulesPath`,
which has broken the sibling branch twice.

### 3. Home Manager: relink or collision?

Home Manager is NixOS-integrated now — one `just switch` applies both, and there
is no `homeConfigurations` output. This host had HM before the restructure
(`nire-tenacity-hm-elly`, the same `user-elly` config durandal used), so its
dotfiles are *probably* already HM-owned symlinks and this is a relink.

```sh
readlink -f ~/.zshrc ~/.bashrc ~/.gitconfig    # into /nix/store => already HM-owned
nix profile list | grep home-manager-path      # present => an old standalone profile
just dotfiles                                  # everything HM will take ownership of
```

Real files rather than symlinks mean collisions. `home-manager-cutover.md` has
the `backupFileExtension` escape hatch and when to remove it again.

### 4. Does it actually build?

```sh
just build
```

Expect this to find things evaluation could not. `jovian.nix` in particular has
**never been evaluated by a host** before this branch, let alone built — two
evaluation errors were already fixed in it blind (`adjustor`, removed from
nixpkgs; `inputs.jovian.decky-loader`, which that flake does not expose).

### 5. Sanity checks worth doing while you are there

- `system.stateVersion` is `25.05` for this host, `23.11` for durandal. Taken
  from the pre-restructure config; the sibling branch's stub said `23.11` for
  both, which was wrong. Confirm against `/etc/os-release` history or Elly.
- `boot.loader.systemd-boot` only — no `efi.canTouchEfiVariables`, matching what
  this host ran. If EFI entries need writing, that is why.
- `boot.initrd.systemd.enable` is **false** — scripted stage 1. Do not enable it
  casually; read `impermanence-stage1.md` first.

## Order of work

1. Push/fetch, get to `93d480d` or later.
2. Checklist items 1 and 2 — before anything is built.
3. `just check`, then `just build`. Fix what surfaces.
4. Checklist item 3, then `just switch`.
5. **Reboot deliberately**, and confirm `/root` was actually rolled back rather
   than merely that the machine came up. A rollback that silently stops looks
   exactly like a working system until the disk fills.
6. Only then consider durandal, which has not been built either.

## What I could not check, and would want checked

- Everything above.
- Whether the handheld stack works at all: `jovian.steam` autostart into the
  plasma session, decky-loader, `handheld-daemon` with `adjustor`. The TDP
  control had a known nixpkgs problem
  (<https://github.com/NixOS/nixpkgs/pull/347279>) noted in the module.
- Whether the peripherals modules (`logitech-g600`, `zsa-moonlander`) are still
  wanted on a handheld. They came from the pre-restructure config.
- Package parity: this host installs the full desktop GUI set — vscode, gimp,
  libre-office, zoom — deliberately, per a decision recorded on the sibling
  branch. Worth re-asking now it is real.

## Conventions, briefly

`CLAUDE.md` and `linux-flake/style-guide.md` are authoritative. The ones most
easily got wrong:

- **`git add` before `nix eval`.** Flakes ignore untracked files, so a new module
  silently does not exist.
- **Do not run `nix fmt`.** The aligned `=` columns are deliberate and treefmt is
  deliberately absent.
- **A module's filename is its attribute name**, and same-named modules *merge*
  rather than conflicting. `just modules` checks for that.
- **A bug recorded in a comment stays in the file**; if it is orphaned by a later
  change, move it to a `history` block at the bottom rather than deleting it.
- Verify refactors with `just diff <ref>`, which says *what* changed rather than
  only that the hash moved.
- Report honestly which you mean: *evaluates*, *builds*, or *runs*. You are the
  first instance that can say the third.
