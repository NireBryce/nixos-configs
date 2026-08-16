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

Three ways to actually run the install, covered separately below: unattended
(`installer-autoinstall-testbed.nix`, a systemd service that mounts the real
disk by its already-known UUIDs and runs `nixos-install --flake` with nobody
driving anything), a graphical Calamares wizard (patched to run the same
`nixos-install --flake` instead of its own generic install,
`installer-calamares.nix`), or the terminal by hand. **Reach for unattended
first if the disk is already partitioned** (a reinstall, or this is the
known machine) -- it needs no desktop session at all, which matters because
GDM/GNOME has not been confirmed to actually come up on the real X270 yet
(a real, hit gap -- see "What's on it" and "What this doc does not cover").
Calamares needs that desktop and is the least proven of the three; the
terminal path is the fallback of last resort, and the only one of the three
with the `nixos-generate-config` step a genuine repartition needs.

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

- `autoinstall-testbed.service` (`installer-autoinstall-testbed.nix`), a
  `systemd` oneshot that waits for network, checks whether the disk already
  has the two exact partitions `hardware-testbed.nix` expects (by UUID --
  never partitions or guesses; if they're not there, it refuses and exits
  loudly rather than touching the disk), then runs the same
  `nixos-install --flake path:/etc/nixos-configs#nire-testbed` the other two
  paths use, unattended. A 10s window at the start allows aborting with
  `systemctl stop autoinstall-testbed` (from SSH, or another console) before
  anything gets mounted. Does **not** auto-reboot when it finishes -- prints
  a message and stops, so there's still a chance to notice something's wrong
  before committing to a reboot.
- Optional unattended wifi for the above: `build-liveusb.sh` prompts for an
  SSID/password at build time (skippable) and bakes a `NetworkManager`
  profile in if given one -- see that script and
  `installer-autoinstall-testbed.nix`'s header for the mechanism and why the
  password ends up in the built image's Nix store regardless (there's no way
  around that for something unattended with nobody present to type it).
  Treat a built `.iso` with credentials baked in as sensitive.
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

## Installing nire-testbed unattended

Only works if the disk is already partitioned the way `hardware-testbed.nix`
expects -- this path never partitions anything (see "What's on it"). If it's
a fresh disk or a different layout, use the terminal path below instead,
which has the `nixos-generate-config` step a repartition needs.

1. `just liveusb` -- answer (or skip) the wifi prompt -- write it to a USB
   stick, boot the X270 from it.
2. If wifi credentials were baked in, it associates on its own; otherwise
   plug in ethernet, or connect wifi by hand (GNOME's NetworkManager applet
   or `nmtui`) so `autoinstall-testbed.service` has network to install with.
3. Watch it (from another machine over SSH is easiest:
   `ssh nixos@<its address>`):
   ```sh
   journalctl -u autoinstall-testbed -f
   ```
   It refuses and exits immediately if the expected partitions aren't found
   -- that's the signal to switch to the terminal path, not a bug to retry.
4. When it finishes, it says so and stops rather than rebooting itself.
   Reboot manually when ready (`reboot`), then remove the USB stick.
5. Update `CLAUDE.md`'s "State" section with the result -- generation
   number, date, whether it actually booted. Same discipline as tenacity's
   first boot: an undated "verified" means *evaluates*, not *booted* -- and
   this whole path is unconfirmed against real hardware regardless (see
   "What this doc does not cover").

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

Nothing about any of the three paths has been run to completion against the
real X270 yet. The hand walkthrough is at least the standard NixOS
flake-install procedure end to end. The other two carry real, specific
unknowns:

- **GDM/GNOME itself has already failed once** on real hardware during this
  work -- booted to a bare TTY with no `display-manager.service` unit at
  all, cause not yet root-caused (the leading theory, unconfirmed, is a
  stale checkout on whichever machine ran `just liveusb` predating the
  commit that added `services.desktopManager.gnome.enable`, not a config
  bug in what's on `main` now -- but that's not confirmed either). Until
  that's understood, **Calamares should be assumed not to come up**, since
  it depends entirely on that same desktop session existing. This is the
  main reason the unattended path exists: it needs no desktop at all.
- **Unattended has its own unknowns**, different ones: whether
  `network-online.target` is actually reached in time (and at all, if wifi
  needs hand-connecting), whether the baked-in `NetworkManager` profile (if
  used) actually associates, and whether `nixos-install --no-root-passwd`
  behaves the same run non-interactively from a `systemd` service as it
  does from an interactive terminal. None of this can be checked from eval
  alone.

Eval-time checks (`just modules`, `nix eval .../isoImage.drvPath`, confirming
the patched `calamares-nixos-extensions` derivation builds with the right
files inside it, confirming the wifi profile populates under `--impure` and
stays empty without it) all pass for all three paths -- but none of that
confirms behavior on the real machine. All of it is only observable by
physically building the ISO and booting it on the X270. Treat every path as
unconfirmed until that happens, and the partition layout (all three) as the
first thing to go wrong if something does.
