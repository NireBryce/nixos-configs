# The live-USB installer, and installing nire-testbed with it

> **Written by Claude Code.** A working note, not documentation.

`nire-installer` (`./installer-configuration.nix`, right next to this doc) is
a NixOS live-USB image, built for one purpose: installing `nire-testbed`
(ThinkPad X270) onto its real disk. It is not a host anyone switches to --
see `nireHost/testbed/hardware/hardware-testbed.nix`'s own header, which has
been carrying a placeholder `fileSystems`/`boot.initrd.*` block since the
host was added, waiting on exactly this.

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
itself once it exists.

## What's on it

- `nixos-generate-config`, `nixos-install`, `parted` and the rest of
  `nixos-install-tools`, from upstream's
  `installer/cd-dvd/installation-cd-minimal.nix` -- the same base profile the
  official minimal ISO uses.
- Flakes, `nix-command`, and `allowUnfree` already on
  (`nire/nix/nix-settings/basic-nix-settings.nix`, imported the same as every
  real host), so `nixos-install --flake` works with no setup.
- NetworkManager instead of the profile's default wpa_supplicant config --
  `nmtui` at the actual keyboard is easier for a laptop being installed in
  person. Firmware for the X270's Intel wireless is on
  (`hardware.enableRedistributableFirmware`).
- SSH, with the same key list `nire/system/ssh/ssh.nix` installs for `elly`
  on every real host -- duplicated by hand rather than imported, because this
  image has no `elly` user (the installer's own account is `nixos`, wheel,
  passwordless sudo). Keep the two lists in sync if a key ever changes.
- `git`, `vim`, `tmux`, `htop`, `gptfdisk`, `btrfs-progs` on top of the base
  profile's own package set.

## Installing nire-testbed with it

1. `just liveusb`, write it to a USB stick, boot the X270 from it.
2. Get on the network -- `nmtui` for wifi, or plug in ethernet -- and confirm
   with `ip a`. SSH in from another machine if that's easier than typing at
   the laptop directly: `ssh nixos@<its address>`.
3. Partition and format the real disk. `hardware-testbed.nix`'s placeholder
   assumes a plain EFI-system-partition-plus-ext4 layout (no LUKS, no btrfs,
   no impermanence -- see that file and `CLAUDE.md`'s safety section for why
   testbed was deliberately given a plain persistent root instead of the
   rollback the other two hosts have). `parted`/`gdisk` plus `mkfs.fat` and
   `mkfs.ext4` are all on the image. If that decision changes before install,
   `flake/doc/disko-impermanence-layout.md`'s generator is the template for
   LUKS + btrfs + impermanence instead -- decide that *before* partitioning,
   not after.
4. Mount the new filesystems at `/mnt` (root at `/mnt`, ESP at `/mnt/boot`),
   then:

   ```sh
   nixos-generate-config --root /mnt
   ```

5. Take the real `fileSystems`/`swapDevices`/`boot.initrd.availableKernelModules`
   block from `/mnt/etc/nixos/hardware-configuration.nix` and use it to
   replace the placeholder block in this repo's
   `nireHost/testbed/hardware/hardware-testbed.nix` -- everything below that
   block (the nixos-hardware import, the CPU/microcode lines) is already real
   and should stay. Get the edited file onto the live system -- `git clone`
   this repo's GitHub remote and edit there, or edit on another machine and
   `scp` the one file over.
6. **`git add` before `nix eval` or `nixos-install`** -- flakes in a git repo
   ignore untracked files, so an edited-but-unadded hardware file silently
   installs the placeholder instead. (`CLAUDE.md`, "Working in this repo".)
7. ```sh
   nixos-install --flake .#nire-testbed --root /mnt
   ```
8. Reboot, remove the USB stick.
9. Update `CLAUDE.md`'s "State" section with the result -- generation number,
   date, and whether it actually booted -- the same way tenacity's first boot
   was recorded. An undated "verified" here means *evaluates*, not *booted*.

## What this doc does not cover

Nothing about this has been run against the real X270 yet. The install steps
above are the standard NixOS flake-install procedure, not a confirmed
account of this machine's install -- treat step 3 in particular (the real
partition layout) as the first thing to go wrong if something does.
