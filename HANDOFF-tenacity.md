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
| `linux-flake/lessons.md` | how the work went wrong in the doing |

## Getting the code

**6 commits are unpushed as of writing.** Ask Elly to push, or you will be
working against a tree that predates tenacity existing at all:

```
282e72e docs: handoff to the instance that will run on tenacity
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
git log --oneline -1     # expect 282e72e or later
```

## Why you exist

**Nothing on this branch has been built or switched.** `origin/main` merged
flake-parts in PRs #28 and #29 and is what these machines run, so the
architecture itself is proven; what is untested is the 172 commits this branch
adds on top. Every "verified"
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

Ordered by how likely each is to be a real problem, which is not the same as how
bad it would be. Two items that *would* be severe are already answered:

> **Elly confirms `root-blank` exists and that both machines' disks are
> formatted the same way.** That resolves what I had flagged as the one
> boot-fatal unknown. Both are still worth a thirty-second confirmation on the
> hardware — they are cheap and the failure mode is initrd — but expect them to
> pass, and do not treat them as blockers.

### 1. Does it build? — the most likely source of real problems

```sh
just check      # both hosts' toplevels + both home activations + module-tree
just build      # this host, no activation
```

Expect this to find things evaluation could not. `jovian.nix` in particular has
**never been evaluated by a host** before this branch, let alone built — two of
its evaluation errors were already fixed blind (`adjustor`, removed from
nixpkgs; `inputs.jovian.decky-loader`, which that flake does not expose). The
handheld stack behind it — decky-loader, `handheld-daemon`, `adjustor` — is
entirely unexercised.

`just check` on darwin only ran `module-tree`; here it runs all five:
`nixos-nire-durandal`, `nixos-nire-tenacity`, `home-nire-durandal`,
`home-nire-tenacity`, `module-tree`.

### 2. Home Manager: relink or collision?

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

### 3. Confirm the disk matches the config — expected to pass

`modules/nireHost/tenacity/hardware/hardware-tenacity.nix` is the January 2026
generator output, reused verbatim on Elly's confirmation that nothing changed.

```sh
lsblk -o NAME,UUID,FSTYPE,MOUNTPOINT
findmnt -no SOURCE,FSTYPE,OPTIONS /  /home /nix /persist /var/log /boot
ls /dev/mapper/
```

Expected: LUKS volume `enc`; btrfs subvolumes `root`, `home`, `nix`, `persist`,
`log`; root filesystem UUID `a99ae3fe-3254-4d6b-9da7-c448a89d166d`; LUKS device
UUID `03b8f5c0-d846-4fde-b533-2a22e8e9975b`; `/boot` vfat `380C-3C39`.

If anything differs, regenerate rather than patch, and wrap the result as a
flake-parts module **in the same commit** — a raw `nixos-generate-config` file
under `modules/` produces `infinite recursion encountered` naming `modulesPath`,
which has broken the sibling branch twice.

### 4. Confirm `root-blank` — expected to pass

This host imports the `boot` category, so `/root` is deleted and recreated every
boot from a snapshot:

```
btrfs subvolume snapshot /mnt/root-blank /mnt/root
```

Elly confirms it is there. Confirming costs nothing and the failure mode is a
machine that does not boot:

```sh
sudo mkdir -p /mnt-check
sudo mount -o subvol=/ /dev/mapper/enc /mnt-check
sudo btrfs subvolume list -o /mnt-check | grep -E 'root-blank|root$'
sudo umount /mnt-check
```

In the unexpected case that it is absent, stop. Creating one is a deliberate act
— it fixes the state this machine returns to on every boot — and is Elly's call,
not yours.

### 5. Smaller things worth checking while you are there

- `system.stateVersion` is `25.05` here, `23.11` on durandal. Taken from the
  pre-restructure config; the sibling branch's stub said `23.11` for both, which
  was wrong.
- `boot.loader.systemd-boot` only — no `efi.canTouchEfiVariables`, matching what
  this host ran. If EFI entries need writing, that is why.
- `boot.initrd.systemd.enable` is **false** — scripted stage 1. Do not enable it
  casually; read `impermanence-stage1.md` first.

## Order of work

1. Push/fetch, get to the tip listed above.
2. **§3 and §4** — the two confirmations. Cheap, and they are the ones that fail
   in initrd rather than at the prompt, so get them out of the way first even
   though both are expected to pass.
3. **§1** — `just check`, then `just build`. Fix whatever surfaces. This is where
   the time will go.
4. **§2** — check what Home Manager is about to take ownership of, then
   `just switch`.
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
