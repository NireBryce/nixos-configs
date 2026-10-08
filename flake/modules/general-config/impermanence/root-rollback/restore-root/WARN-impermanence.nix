# WARNING: IMPORTING THIS DELETES / ON EVERY BOOT. If your disk looks like
# the one described below, it will delete yours. Know what you're doing.
#
# This file, flake/modules/general-config/impermanence/root-rollback/
# restore-root/WARN-impermanence.nix, is the module that wipes the root
# filesystem at boot on the hosts that import the `impermanence` category.
#
# ── what this does, and why ─────────────────────────────────────────────────
#
# On every boot, before the real root filesystem is mounted, this deletes
# the btrfs subvolume that `/` lives on and replaces it with a fresh copy of
# an empty one. Whatever the last boot wrote to `/` is gone. What survives
# is only what is stored somewhere else on purpose: /nix, /home, /var/log,
# and a list of individual paths kept on /persist and mounted back into
# place (the `environment.persistence` block below).
#
# Why do that to a machine on purpose? Because a normal root filesystem
# collects state nobody asked for, and nothing tells you:
#
# - A tool writes a config file under /etc by hand, the machine depends on
#   it, and the Nix config no longer describes the machine.
# - A service keeps something important in /var/lib, and nobody knows it's
#   important until a reinstall loses it.
# - Leftovers from things removed months ago keep running or keep being read.
#
# With the wipe, anything not declared is gone at the next boot, so every
# piece of state that matters has to be written down in this repo -- the
# persistence lists are that written-down list. Forgetting one fails loudly
# and early (the wifi password is gone tomorrow), instead of silently and
# years later.
#
# Which hosts: the ones whose host-config/*-configuration.nix imports the
# `impermanence` category -- nire-durandal and nire-tenacity. nire-cube
# deliberately does not (plain persistent root; see its header). Hosts reach
# this file only through the category, never by its module name, so
# renaming the file changes no host file. host-config/hosts.nix and the
# host files are the current answer; this list is as of 2026-09-28.
#
# ── background: the disk, and the boot it runs in ───────────────────────────
#
# Both hosts that import this share one layout: a LUKS-encrypted partition
# (the LUKS *volume* is named `enc`; opened, it appears as /dev/mapper/enc)
# holding one btrfs filesystem. btrfs splits that filesystem into
# *subvolumes* -- separately mountable trees that share the disk's space.
# The host's hardware file (host-config/<host>/hardware/hardware-<host>.nix)
# mounts them, and owns their mount options:
#
#   btrfs top level (subvol=/)       never mounted normally
#   ├── root         ->  /           WIPED: deleted and re-copied each boot
#   ├── root-blank                   the empty snapshot `root` is copied from
#   ├── nix          ->  /nix        kept: the store
#   ├── home         ->  /home       kept
#   ├── log          ->  /var/log    kept
#   ├── persist      ->  /persist    kept: the paths listed below live here
#   └── secureboot   ->  /var/lib/sbctl   kept (durandal only)
#
# `root-blank` must exist, and no host's config creates it -- it is made
# once, at install time, by hand (_disko/impermanence-luks-btrfs.nix
# describes the layout but no host imports it). Without it the rollback
# deletes /root and then fails to replace it.
#
# The wipe has to happen at a precise moment: after the disk is unlocked,
# before `/` is mounted. That moment only exists inside the *initrd* -- the
# small temporary filesystem the kernel boots first, whose one job is to
# unlock the disk and mount the real root at /sysroot before handing over.
# Here the initrd runs systemd ("systemd stage 1"), so the wipe is an
# ordinary systemd service, `restore-root`, that the initrd starts at the
# right point. (Not to be confused with boot.loader.systemd-boot, the EFI
# boot menu, which both hosts also use. Similar names, unrelated things.)
#
# The other half is the impermanence NixOS module, from the `impermanence`
# flake input. It provides `environment.persistence`: for every path listed
# there, it bind-mounts /persist/<path> over <path> during activation, so
# the file looks like it never left. This file uses that option without
# importing the module. general-config/system/impermanence/
# declare-persistence-option.nix imports it once, for every NixOS host --
# nire-cube included, since its *-persist.nix modules need the option to
# exist even when they set nothing. A second import from here would be a
# second declaration of the same option (two different modules importing
# one file aren't deduplicated), and evaluation stops with "The option
# `environment.persistence' ... is already declared".
#
# ── where restore-root sits in the boot ─────────────────────────────────────
#
# restore-root runs once the root device exists and before anything mounts
# it. Everything in the `services.restore-root` block below is making that
# one sentence true. The initrd's boot, with this unit in it:
#
#   kernel starts initrd systemd
#     │
#     ├─ systemd-cryptsetup@enc.service   asks for the passphrase, unlocks
#     ├─ dev-mapper-enc.device            /dev/mapper/enc exists
#     ├─ initrd-root-device.target        the root device exists and udev
#     │                                   has finished with it
#     │
#     ├─ restore-root.service  ◀── HERE   mount top level at /mnt,
#     │                                   delete root, snapshot root-blank
#     │                                   as root, unmount
#     │
#     ├─ sysroot.mount                    the new, empty root at /sysroot
#     └─ switch to the real system  ->  activation bind-mounts /persist/...
#
# What follows from that:
#
# - Ordered too early (before the device), it fails; too late (after
#   sysroot.mount), it deletes a mounted root. Both edges are pinned below.
# - If it fails, the boot has to stop. A failed unit nothing depends on is
#   invisible: the machine boots with / un-wiped and looks perfectly fine.
#   OnFailure = emergency.target turns a failure into a halted boot.
# - If the machine is *resuming from hibernation*, it must not run at all:
#   the saved memory image expects the old / to still be there. The
#   "hibernation stays off" block below covers how, and why that took more
#   than one setting.
#
# ── how the unit finds the LUKS units ───────────────────────────────────────
#
# To order itself after the unlock, the unit needs the names of two units
# systemd *generates*: dev-mapper-<volume>.device and
# systemd-cryptsetup@<volume>.service. You'd expect to just write them in.
# The catch is that ordering After= a unit that doesn't exist is not an
# error -- systemd ignores it. Write the wrong name and the ordering
# silently vanishes, with nothing to say so.
#
# So the names are built from the same option that makes systemd generate
# the units in the first place:
#
#   boot.initrd.luks.devices.enc            (host's hardware file)
#     -> field 1 of the initrd's crypttab   (nixpkgs luksroot.nix)
#     -> systemd-cryptsetup@enc.service     (systemd-cryptsetup-generator)
#
#   this file reads the same attribute names -> luksDeviceUnits,
#                                               luksCryptUnits
#
# It's the volume name, not the hostname: the unit is named after field 1
# of the crypttab line, which is the attribute name. A host that renames
# its volume gets the right ordering with no edit here. Evaluated on both
# hosts, 2026-09-28: requires = [ dev-mapper-enc.device ], after =
# [ initrd-root-device.target dev-mapper-enc.device
#   systemd-cryptsetup@enc.service ].
#
# The device to mount is derived the same way: rootDevice is whatever the
# host's fileSystems."/" says (a /dev/disk/by-uuid/... path), so this file
# names no host's device.
#
# ── what fails silently ─────────────────────────────────────────────────────
#
# - A rollback that stops running looks like a working machine. invariants.nix
#   catches the structural ways it can stop: restore-root gone, not wanted
#   by initrd.target, not before sysroot.mount, systemd stage 1 off, btrfs
#   missing from the initrd. It gates all of these on restore-root
#   existing, so a host that never imported this is exempt.
# - Hibernation has a desktop half. With the kernel refusing hibernation,
#   KDE's PowerDevil asking for hybrid sleep (suspend + hibernation image)
#   gets CanHybridSleep=no from logind and *drops the request* -- suspend
#   stops working entirely, no fallback to plain suspend. kde-sleepmode.nix,
#   beside this file, pins PowerDevil's SleepMode to 1 (suspend to RAM);
#   the two have to agree. invariants.nix checks nohibernate and all three
#   Allow* settings.
# - New state is lost quietly. A service added later whose state lives
#   under / starts fresh every boot until someone persists it. `just
#   root-drift`, on the host with sudo, lists what's on / that no
#   persistence entry covers.
# - `${...}` inside the script string is Nix interpolation, comments
#   included. `${rootDevice}` is meant; anything else is a bug.
#
# ── how to change this safely ───────────────────────────────────────────────
#
# Read skill `impermanence-initrd` first -- the shell's view of disks and
# mounts on these hosts is namespaced and misleading. Then:
#
# 1. Evaluate both hosts' toplevel and run `just check` (invariants.nix
#    throws during eval). Compare the unit before/after with `just diff`,
#    not only the hash.
# 2. On hardware, confirm the wipe actually ran: `sudo btrfs subvolume list
#    -a /` shows /root with a subvolid far above its neighbours after each
#    boot, and the boot journal shows the "deleting /root subvolume..."
#    lines from the script below.
# 3. If a boot stops at emergency, pick the previous generation in the
#    systemd-boot menu.
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = { config, ... }:
    let
        # Every name here comes from the host's own config, so this file
        # names no host, volume, or device -- "how the unit finds the
        # LUKS units" above.
        rootDevice      = config.fileSystems."/".device;
        luksVolumes     = builtins.attrNames config.boot.initrd.luks.devices;
        luksDeviceUnits = map (v: "dev-mapper-${v}.device") luksVolumes;
        luksCryptUnits  = map (v: "systemd-cryptsetup@${v}.service") luksVolumes;
    in {
        # ── persistence ─────────────────────────────────────────────────

        # A new machine-id every boot would make each boot a stranger to
        # the journal (its directory is per machine-id).
        environment.etc.machine-id.source = "/persist/etc/machine-id";

        # The state every impermanence host needs. State that belongs to
        # one service lives in a `<name>-persist.nix` beside that
        # service's module instead -- desktop-env/jovian/
        # jovian-persist.nix holds /etc/hhd, system/networking/
        # tailscale-persist.nix holds /var/lib/tailscale, and there are a
        # few more (`find -name '*-persist.nix'`). Filed as a sibling,
        # each is collected by the same category as its service, so
        # /etc/hhd persists only on hosts that run handheld-daemon.
        # `directories` and `files` are lists, so their entries join
        # these.
        environment.persistence."/persist" = {
            directories = [
                "/var/lib/bluetooth"
                "/var/lib/nixos"
                "/var/lib/systemd/coredump"
                "/etc/NetworkManager/system-connections"
                "/var/lib/flatpak"
            ];
            files = [
                "/etc/ssh/ssh_host_ed25519_key"
                "/etc/ssh/ssh_host_ed25519_key.pub"
                "/etc/ssh/ssh_host_rsa_key"
                "/etc/ssh/ssh_host_rsa_key.pub"
            ];
        };

        # sudo's first-use lecture is remembered under /var/db/sudo,
        # which the wipe forgets -- so it would lecture after every boot.
        security.sudo.extraConfig = ''
            Defaults lecture = never
        '';

        # ── hibernation stays off ───────────────────────────────────────
        #
        # A hibernation image is a snapshot of a system whose / is about
        # to be deleted and re-copied; resuming it restores a kernel
        # holding open files that are gone.
        #
        # Nothing in this config asks for hibernation, and there's no
        # swap configured, so this looks like it should already be off.
        # It wasn't: on tenacity, systemd-gpt-auto-generator found a
        # swap partition by its GPT type, turned it on, and pointed the
        # resume device at it -- with `swapDevices = []` and no `resume=`
        # anywhere (seen in /proc/swaps and /sys/power/resume). So the
        # off switch has to hold whatever systemd discovers, and
        # `nohibernate` is the kernel's own. The sleep.conf entries make
        # logind stop *offering* these states rather than failing them;
        # the KDE half is under "what fails silently" above.
        #
        # settings.Sleep because `systemd.sleep.extraConfig` was removed
        # in 26.11.
        boot.kernelParams = [ "nohibernate" ];
        systemd.sleep.settings.Sleep = {
            AllowHibernation          = false;
            AllowHybridSleep          = false;
            AllowSuspendThenHibernate = false;
        };

        # ── the rollback unit ───────────────────────────────────────────
        boot.initrd = {
            enable = true;
            # Puts the btrfs tools in the initrd, for the script.
            supportedFilesystems = [ "btrfs" ];

            systemd = {
                enable = true;

                # emergencyAccess is left at its default, false. `true`
                # would give an *unauthenticated* root shell, reachable
                # before the LUKS volume is open -- a root shell for
                # anyone holding the handheld. OnFailure below halts the
                # boot either way, which is what matters, and root has no
                # password to type anyway (users.mutableUsers = false;
                # no root hash is set). Recovery is the previous
                # generation in the systemd-boot menu. If an initrd shell
                # is ever really needed, the option also takes a password
                # hash: `oneOf [ bool (nullOr (passwdEntry str)) ]`.

                services.restore-root = {
                    description = "Roll /root back to the blank btrfs snapshot";

                    # The diagram in "where restore-root sits in the
                    # boot", as unit ordering.
                    #
                    # initrd-root-device.target is the host-generic
                    # point: reached once the root device exists,
                    # whatever the volume is called. Being After= a
                    # .device unit also means udev has finished with it,
                    # so the /dev/disk/by-uuid symlink in rootDevice
                    # exists -- a real barrier, not a poll.
                    #
                    # Both requires and after on the device, because in
                    # systemd they're independent: Requires= pulls a unit
                    # in, After= orders against it, and systemd.unit(5)
                    # says to pair them. Requires= alone can start before
                    # the device is there; After= alone runs anyway and
                    # fails.
                    wantedBy = [ "initrd.target" ];
                    requires = luksDeviceUnits;
                    after    = [ "initrd-root-device.target" ] ++ luksDeviceUnits ++ luksCryptUnits;
                    before   = [ "sysroot.mount" ];

                    unitConfig = {
                        # Opt out of systemd's implicit ordering (after
                        # sysinit.target and basic.target) so the only
                        # ordering is the explicit one above.
                        DefaultDependencies = "no";

                        # Skips the wipe when the kernel command line
                        # has `resume=`. A second line only: as the
                        # hibernation block above describes, systemd
                        # can set up resume without that parameter, and
                        # on tenacity this condition would have passed
                        # and let the wipe go ahead. nohibernate is what
                        # closes it.
                        ConditionKernelCommandLine = [ "!resume" ];

                        # A failed rollback halts the boot instead of
                        # quietly leaving / un-wiped.
                        OnFailure = "emergency.target";
                    };

                    serviceConfig.Type = "oneshot";

                    # Runs under `set -e` (nixpkgs wraps every unit
                    # script that way: makeJobScript in
                    # nixos/lib/systemd-lib.nix), so the first failing
                    # command fails the unit and OnFailure fires. The
                    # tools are there: btrfs via supportedFilesystems,
                    # mount/umount from systemd's extraBin, cut from
                    # coreutils in initrdBin. PATH is /bin:/sbin.
                    #
                    # The loop comes first because by this point root/
                    # holds nested subvolumes (observed: srv,
                    # var/lib/portables, var/lib/machines, var/tmp), and
                    # `btrfs subvolume delete` refuses a subvolume that
                    # has others inside it. Deleting them has caused
                    # nothing worse than harmless-looking
                    # systemd-tmpfiles errors.
                    script = ''
                        mkdir -p /mnt

                        # The top level, where the subvolumes are visible.
                        mount -o subvol=/ ${rootDevice} /mnt

                        btrfs subvolume list -o /mnt/root |
                        cut -f9 -d' ' |
                        while read subvolume; do
                            echo "deleting /$subvolume subvolume..."
                            btrfs subvolume delete "/mnt/$subvolume"
                        done

                        echo "deleting /root subvolume..."
                        btrfs subvolume delete /mnt/root

                        echo "restoring blank /root subvolume..."
                        btrfs subvolume snapshot /mnt/root-blank /mnt/root

                        umount /mnt
                    '';
                };
            };
        };
    };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-10 — migrated from boot.initrd.postResumeCommands (scripted stage
# 1) to the systemd unit, forced by the 2026-08-07 nixpkgs bump: it made
# boot.initrd.systemd.enable default true, deprecated scripted initrd (removal
# in 26.11), and systemd stage 1 fails an assertion on postResumeCommands, so
# the switch was atomic. The working note, wiki/impermanence-stage1-
# migration.md, was removed 2026-09-05 (git history). What the old mechanism
# did that a revert would bring back:
#
# - `udevadm settle` guarded the mount: scripted stage 1 hardcoded
#   /dev/mapper/enc (created synchronously by cryptsetup), while
#   fileSystems."/" is a by-uuid path udev creates asynchronously -- losing
#   that race was a silent non-wipe. After= the device units replaced it.
# - `boot.kernelParams = [ "boot.shell_on_fail" ]` made stage-1-init.sh's
#   fail() offer a shell; OnFailure = emergency.target replaced it.
# - `if ! mount ...; then fail; fi` guards: without them a failed mount left
#   every later command failing harmlessly against an empty /mnt. `set -e`
#   replaced them.
# - postResumeCommands ran *after* the resume attempt, so a successful
#   hibernation resume skipped the wipe for free. The unit has no such
#   ordering and could race a resuming boot -- hence
#   ConditionKernelCommandLine, then nohibernate once tenacity showed resume
#   set up with no `resume=` (found 2026-08-10). Never fired; one flat
#   battery during suspend away. lessons-learned §28 (including the wrong
#   "tenacity has no swap" assessment that started it).
# - The template-injection trap (never write an @placeholder@ token in a
#   scripted hook string, comments included -- a later substituteInPlace
#   pass expands it) died with the mechanism. Full account: skill
#   `impermanence-initrd`.
#
# 2026-08-10 — emergencyAccess = true was carried for the first boot of the
# systemd-stage-1 branch (debugging a pre-LUKS failure needs an
# unauthenticated shell -- a knowingly-accepted hole), removed once the
# rollback was confirmed by subvolid.
#
# 2026-08-10 — the suspend hang on tenacity ("suspend hangs with the fan
# on"): KDE requested hybrid sleep, systemd-hybrid-sleep.service took ~19s
# and ~2.3G of writes. Not a regression from the migration (the journal
# shows the same under scripted stage 1). Disabling hibernation then broke
# suspend entirely until PowerDevil's SleepMode changed from 2 to 1
# (lessons-learned §30). An earlier version of this comment claimed a
# refused hybrid-sleep request degrades to plain s2idle; it does not --
# logind still reported CanSuspend=yes and /sys/power/state `freeze mem`,
# only the request was dropped. /sys/power/mem_sleep on tenacity is
# `[s2idle]` alone, no `deep`.
#
# 2026-08-10 — the nested subvolumes under root/ (srv, var/lib/portables,
# var/lib/machines, var/tmp) were observed on the machine, which is why the
# delete loop exists.
#
# 2026-08-09 — fileSystems options moved out: this module and the host
# hardware configs both declared mount options, and `options` is
# `listOf str`, so the definitions concatenated (every option twice --
# harmless to mount, but the one-owning-module rule broken). The hardware
# configs own them; verified unchanged with `just diff`. The disabled block
# stayed here commented out until 2026-09-28, then was deleted: compress=zstd
# on /, /home, /nix, /persist, /var/log, /var/lib/sbctl (plus noatime on all
# but /home), and neededForBoot on /persist, /var/log, /var/lib/sbctl.
# Adding any of it back here doubles what the hardware file declares.
#
# 2026-08-09 — the ordering fix in ad38ffb: the old unit hardcoded
# `requires = [ "dev-mapper-enc.device" ]`, `after = [ "dev-mapper-enc.device"
# "systemd-cryptsetup@nire-durandal.service" ]`, and mounted /dev/mapper/enc.
# The crypt unit is named after the *volume*, not the host (luksroot.nix,
# stage1Crypttab), so systemd-cryptsetup@nire-durandal.service never existed
# anywhere -- the After= was a silent no-op (dev-mapper-enc.device beside it
# was what actually ordered things), and interpolating networking.hostName
# would have been wrong the same way on tenacity. Deriving from
# boot.initrd.luks.devices fixed it; durandal's generated values came out
# byte-identical (`just diff`). The confusion with boot.loader.systemd-boot
# is the likeliest reason ad38ffb's first attempt looked finished.
#
# 2026-09-28 — rewritten as a talk-style explanation (skill
# `explain-tricky-code`): the body's comments were reorganised into the
# header and next to the lines they explain, and the dated incident detail
# moved here from the body.
