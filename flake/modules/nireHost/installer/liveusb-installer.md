# The live-USB installer, and installing nire-testbed with it

> **Written by Claude Code.** A working note, not documentation.

`nire-installer` (`./installer-configuration.nix`, right next to this doc) is
a NixOS live-USB image, built for one purpose: installing `nire-testbed`
(ThinkPad X270) onto its real disk. It is not a host anyone switches to.
`nireHost/testbed/hardware/hardware-testbed.nix` already carries real
`fileSystems`/`boot.initrd.*` values as of 2026-08-16 (read off the actual
partitioned disk), so this doc's steps 4-6 below are only live again if that
disk ever gets repartitioned -- `by-uuid` device paths are generated fresh by
`mkfs` every time, so a reformat always needs a fresh
`nixos-generate-config` and a fresh edit to that file, embedded flake or not.

This whole feature -- this doc, the config, `installer-iso.nix` and
`build-liveusb.sh` -- lives together in `flake/modules/nireHost/installer/`,
deliberately grouped, rather than split across `modules/`/`scripts/`/`doc/`
the way the rest of the repo is. See `installer-configuration.nix`'s header
for why that's safe.

## Building it

```sh
just liveusb
```

Dispatches to `./build-liveusb.sh`, which builds
`.#liveusb-testbed-installer` and prints the resulting `.iso` path plus the
`dd` command to write it -- it does not run `dd` itself. Writing the wrong
`/dev/sdX` is unrecoverable, so confirm the target with `lsblk` before
running the command it prints.

Equivalent by hand:

```sh
nix build .#liveusb-testbed-installer
ls result/iso/
```

x86_64-linux only, same as the other NixOS hosts here: there is no remote
builder or binfmt from `nire-lysithea` (aarch64-darwin), so this has to be
built from `nire-durandal` or `nire-tenacity`, or from the live environment
itself once it exists. Graphical now (see below), so expect a noticeably
bigger closure and longer first build than the old minimal profile.

## What's on it

- A GNOME live desktop -- upstream's `installer/cd-dvd/installation-cd-graphical-base.nix`,
  not the separate Calamares installer wizard. This is still a hand-partition
  plus `nixos-install --flake` install, same as always; the graphical session
  is here for a browser, not for Calamares' own generic-NixOS install flow.
  `nixos-generate-config`, `nixos-install`, `parted` and the rest of
  `nixos-install-tools` are still on it, same as the old minimal profile.
- Flakes, `nix-command`, and `allowUnfree` already on
  (`nire/nix/nix-settings/basic-nix-settings.nix`, imported the same as every
  real host), so `nixos-install --flake` works with no setup.
- NetworkManager (`nmtui`, or the GNOME applet) instead of the base profile's
  default wpa_supplicant config. Firmware for the X270's Intel wireless is on
  (`hardware.enableRedistributableFirmware`).
- SSH, with the same key list `nire/system/ssh/ssh.nix` installs for `elly`
  on every real host -- duplicated by hand rather than imported, because this
  image has no `elly` user (the installer's own account is `nixos`, wheel,
  passwordless sudo). Keep the two lists in sync if a key ever changes.
- This whole flake, baked in at `/etc/nixos-configs` (`environment.etc`,
  sourced from `inputs.self`). Booting the image is enough on its own to
  install from -- no network, no `git clone`, needed just to get the config
  onto the live system. It's a symlink into the read-only Nix store, so it's
  real but not editable in place -- see step 5 below for what that means.
- `gh`, alongside `git` -- `gh auth login`'s device-code flow needs a
  browser to complete, which is the actual reason this image is graphical
  now: it turns a plain `git clone` into one with push access, so an edit
  made on the live system (step 5) can be committed and pushed from there
  directly instead of copied back by hand afterward.
- `vim`, `tmux`, `htop`, `gptfdisk`, `btrfs-progs` on top of the base
  profile's own package set.

## Installing nire-testbed with it

1. `just liveusb`, write it to a USB stick, boot the X270 from it.
2. Get on the network -- the GNOME NetworkManager applet or `nmtui` for
   wifi, or plug in ethernet -- and confirm with `ip a`. SSH in from another
   machine if that's easier than typing at the laptop directly:
   `ssh nixos@<its address>` (loses the GUI browser `gh auth login` wants,
   though -- do that step at the actual screen).
3. **If the disk is already partitioned the way `hardware-testbed.nix`
   expects** (i.e. this is a first install, or a reinstall onto the same,
   unwiped partitions), skip to step 7 -- `/etc/nixos-configs` already has
   the right `fileSystems` values baked in and no edit is needed.

   Otherwise (fresh disk, repartitioning, different layout), partition and
   format first: a plain EFI-system-partition-plus-ext4 layout (no LUKS, no
   btrfs, no impermanence -- see `hardware-testbed.nix` and `CLAUDE.md`'s
   safety section for why testbed was deliberately given a plain persistent
   root instead of the rollback the other two hosts have). `parted`/`gdisk`
   plus `mkfs.fat` and `mkfs.ext4` are all on the image. If that decision
   changes before install, `flake/doc/disko-impermanence-layout.md`'s
   generator is the template for LUKS + btrfs + impermanence instead --
   decide that *before* partitioning, not after.
4. Mount the new filesystems at `/mnt` (root at `/mnt`, ESP at `/mnt/boot`),
   then:

   ```sh
   nixos-generate-config --root /mnt
   ```

5. Get a real, writable, push-capable copy of this repo, rather than editing
   the read-only `/etc/nixos-configs`:

   ```sh
   gh auth login       # opens a browser for the device-code flow
   gh repo clone NireBryce/nixos-configs ~/nixos-configs
   ```

   Take the real `fileSystems`/`swapDevices`/`boot.initrd.availableKernelModules`
   block from `/mnt/etc/nixos/hardware-configuration.nix` and use it to
   replace the equivalent block in
   `~/nixos-configs/flake/modules/nireHost/testbed/hardware/hardware-testbed.nix`
   -- everything below that block (the nixos-hardware import, the
   CPU/microcode lines) is already real and should stay.

   `git add` before going further -- flakes in a git repo ignore untracked
   files, so an edited-but-unadded hardware file silently installs the old
   values instead (`CLAUDE.md`, "Working in this repo"). Then commit and
   push, so the edit is in the real repo and not just on a USB stick that's
   about to get unplugged:

   ```sh
   git -C ~/nixos-configs add flake/modules/nireHost/testbed/hardware/hardware-testbed.nix
   git -C ~/nixos-configs commit -m "fix(testbed): real fileSystems from this install"
   git -C ~/nixos-configs push
   ```

   No `gh`/network access, or don't want to push yet? `cp -r
   /etc/nixos-configs ~/nixos-configs` still works as an offline fallback --
   it has no `.git` at all (Nix's git fetcher drops it fetching `self` into
   the store), so `nixos-install --flake path:~/nixos-configs#nire-testbed`
   (note the `path:` prefix, needed for a directory with no git tracking at
   all) is what picks it up in step 7 instead. Just remember the edit only
   exists on this USB session until it's copied back into the real repo by
   hand afterward.
6. (Covered above -- committed and pushed as part of step 5.)
7. ```sh
   nixos-install --flake ~/nixos-configs/flake#nire-testbed --root /mnt
   ```

   (`path:/etc/nixos-configs#nire-testbed`, no edit needed, if step 3 sent
   you straight here.)
8. Reboot, remove the USB stick.
9. Update `CLAUDE.md`'s "State" section with the result -- generation number,
   date, and whether it actually booted -- the same way tenacity's first boot
   was recorded. An undated "verified" here means *evaluates*, not *booted*.

## What this doc does not cover

Nothing about this has been run against the real X270 yet. The install steps
above are the standard NixOS flake-install procedure, not a confirmed
account of this machine's install -- treat step 3 in particular (the real
partition layout) as the first thing to go wrong if something does.
