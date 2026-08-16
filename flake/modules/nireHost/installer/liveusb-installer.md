# The live-USB installer, and installing nire-testbed with it

> **Written by Claude Code.** A working note, not documentation.

`nire-installer` (`./installer-configuration.nix`, right next to this doc) is
a NixOS live-USB image, built for one purpose: installing `nire-testbed`
(ThinkPad X270) onto its real disk. It is not a host anyone switches to.
`nireHost/testbed/hardware/hardware-testbed.nix` already carries real
`fileSystems`/`boot.initrd.*` values as of 2026-08-16 (read off the actual
partitioned disk), so the repartitioning steps in both walkthroughs below are
only live again if that disk ever gets repartitioned -- `by-uuid` device
paths are generated fresh by `mkfs` every time, so a reformat always needs a
fresh `nixos-generate-config` and a fresh edit to that file, embedded flake
or Calamares or not.

This whole feature -- this doc, the config, `installer-iso.nix` and
`build-liveusb.sh` -- lives together in `flake/modules/nireHost/installer/`,
deliberately grouped, rather than split across `modules/`/`scripts/`/`doc/`
the way the rest of the repo is. See `installer-configuration.nix`'s header
for why that's safe.

Two ways to actually run the install, covered separately below: a graphical
Calamares wizard (patched to run `nixos-install --flake` instead of its own
generic install, `installer-calamares.nix`), or the terminal by hand. Try
Calamares first -- it's the reason this image is graphical at all -- but
nothing about the patched wizard has been run against real hardware yet
(see "What this doc does not cover"), so the terminal path stays documented
as the fallback if it fails or hangs mid-wizard.

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

- A real GNOME live desktop (`services.desktopManager.gnome.enable` + `gdm`,
  `installer-calamares.nix`) with autologin as `nixos`. **Correction**: for a
  while this was believed to come from
  `installer/cd-dvd/installation-cd-graphical-base.nix` alone, but that file
  only turns on `services.xserver.enable` -- no desktop manager at all --
  confirmed by reading it directly. Before this fix, `nire-installer` booted
  to a bare LightDM greeter with nothing to log into, despite this doc and
  `installer-configuration.nix`'s own header claiming otherwise. Recorded
  here since it was a real, shipped gap, not hypothetical.
- Calamares (`installer-calamares.nix`), patched so its `nixos` job runs
  `nixos-install --flake path:/etc/nixos-configs#nire-testbed` against
  whatever the wizard's own partition/mount pages set up, instead of
  generating a generic `configuration.nix` the way it does by default. The
  wizard's `locale`/`users`/`packagechooser` pages are dropped from the
  sequence -- the target flake already declares all of that -- `keyboard`
  stays (it has a live effect on the running session, useful for the
  partition page's own text entry). See `installer-calamares.nix` and
  `config/calamares-settings.conf`/`config/calamares-nixos-main.py` for the
  full mechanism.
  `nixos-generate-config`, `nixos-install`, `parted` and the rest of
  `nixos-install-tools` are still on it too, for the terminal path.
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
  Calamares' patched `nixos` job reads from this same path directly.
- `gh`, alongside `git` -- `gh auth login`'s device-code flow needs a
  browser to complete, which is the actual reason this image is graphical
  at all: it turns a plain `git clone` into one with push access, so an edit
  made on the live system (step 5, terminal path) can be committed and
  pushed from there directly instead of copied back by hand afterward.
- `vim`, `tmux`, `htop`, `gptfdisk`, `btrfs-progs` on top of the base
  profile's own package set.

## Installing nire-testbed with Calamares

1. `just liveusb`, write it to a USB stick, boot the X270 from it. Lands on
   a GNOME desktop, autologged in as `nixos`.
2. Get on the network (GNOME's NetworkManager applet or `nmtui`), then open
   Calamares from the desktop.
3. Walk the wizard: welcome, keyboard layout, partition the real disk
   (a plain EFI-system-partition-plus-ext4 layout -- no LUKS, no btrfs, no
   impermanence, see `hardware-testbed.nix` and `CLAUDE.md`'s safety section
   for why), summary, then let it run.
4. **If the disk was just repartitioned differently than what's already in
   `hardware-testbed.nix`** (a fresh disk, not a reinstall onto the same
   layout), the install will still run against the *old* `fileSystems`
   values baked into `/etc/nixos-configs` -- Calamares' wizard doesn't
   regenerate that file. Cancel before the `exec` phase and use the terminal
   path below instead, which has the `nixos-generate-config` step this needs.
5. When it finishes, reboot and remove the USB stick.
6. Update `CLAUDE.md`'s "State" section with the result -- generation number,
   date, whether it actually booted, and whether Calamares itself launched
   and completed cleanly (this is the first real run of the patched wizard --
   see "What this doc does not cover"). Same discipline as tenacity's first
   boot: an undated "verified" means *evaluates*, not *booted*.

## Installing nire-testbed by hand (fallback, or if the disk needs repartitioning)

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

Nothing about either path has been run against the real X270 yet. The hand
walkthrough is at least the standard NixOS flake-install procedure end to
end; the Calamares path is considerably less proven -- eval-time checks
(`just modules`, `nix eval .../isoImage.drvPath`, and confirming the patched
`calamares-nixos-extensions` derivation actually builds with the right files
inside it) all pass, but none of that can confirm Calamares actually
launches on real GNOME/GDM hardware, that the trimmed wizard flow behaves
correctly end to end, that the patched `main.py` runs without a Python-level
error under Calamares' own interface loader, or that `pkexec` succeeds
non-interactively in that session. All of that is only observable by
physically building the ISO and booting it on the X270 -- treat the whole
Calamares path as unconfirmed until that happens, and the partition layout
(both paths) as the first thing to go wrong if something does.
