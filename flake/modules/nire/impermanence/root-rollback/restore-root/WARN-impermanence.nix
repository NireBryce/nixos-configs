{ lib, ... }:
    let
        # The attribute name comes from the filename -- renaming this file
        # renames the module, and dirsAsCategory follows the filename, so
        # category membership moves with it. But anything importing it by
        # literal name would break: relevant, for a module that deletes /root.
        # See AGENTS.md, "A module's name is its filename".
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, ... }:
        let
            # The filesystem holding the root subvolume. The script mounts its
            # btrfs top level to reach the subvolumes; taking it from fileSystems
            # stays unambiguous even if a host ever unlocks more than one volume.
            rootDevice = config.fileSystems."/".device;

            # Ordering for the rollback unit. systemd names the crypt unit after
            # the *volume*, not the host: boot.initrd.luks.devices.<n> becomes
            # field 1 of the initrd crypttab (nixpkgs luksroot.nix,
            # stage1Crypttab) and systemd-cryptsetup-generator derives
            # systemd-cryptsetup@<that field>.service from it. Deriving rather
            # than hardcoding is what keeps a host from ordering After= a unit
            # that is never generated -- a silent no-op, not an error. That
            # happened once (ad38ffb); see the history section at the bottom.
            luksVolumes     = builtins.attrNames config.boot.initrd.luks.devices;
            luksDeviceUnits = map (v: "dev-mapper-${v}.device") luksVolumes;
            luksCryptUnits  = map (v: "systemd-cryptsetup@${v}.service") luksVolumes;
        in {
            # WARNING: IF YOU HAVE A SIMILAR LAYOUT TO MY LUKS SETUP, IMPORTING THIS WILL DELETE YOUR ROOT ON BOOT, so like, know what you're doing

            # filesystems -- disabled 2026-08-09, the host hardware configs own
            # these now. They concatenated rather than overrode; see history at
            # the bottom of this file before re-enabling any of them.
            #
            # fileSystems."/".options                     = [ "compress=zstd" "noatime" ];
            # fileSystems."/home".options                 = [ "compress=zstd" ];
            # fileSystems."/nix".options                  = [ "compress=zstd" "noatime" ];
            # fileSystems."/persist".options              = [ "compress=zstd" "noatime" ];
            # fileSystems."/persist".neededForBoot        = true;
            # fileSystems."/var/log".options              = [ "compress=zstd" "noatime" ];
            # fileSystems."/var/log".neededForBoot        = true;
            # fileSystems."/var/lib/sbctl".options        = [ "compress=zstd" "noatime" ];
            # fileSystems."/var/lib/sbctl".neededForBoot  = true;

            # The impermanence NixOS module itself (the environment.persistence
            # declaration) is NOT imported here. It lives in
            # nire/system/impermanence/declare-persistence-option.nix, imported
            # unconditionally via the `system` category, so the option is
            # declared once for every host -- including ones that wipe nothing
            # (originally nire-testbed, since removed; nire-cube is the current
            # example).
            #
            # Do not import it from here as well. Two DIFFERENT named modules
            # each importing inputs.impermanence.nixosModule are two distinct
            # declaration sites as far as the module system is concerned --
            # not deduplicated the way two categories resolving to the literal
            # same flake.modules.nixos.<name> are -- and evaluation fails with
            # "The option `environment.persistence' ... is already declared".
            # Confirmed on durandal with both imports present. Nothing else
            # changes: persistence.<...> below works exactly as before, the
            # option is just declared from the other file now.
            environment.etc.machine-id.source = "/persist/etc/machine-id";

            # This is not the only definition of this option. Host-specific
            # persistence -- state that only matters to a particular category,
            # not to every host importing `impermanence` -- is declared next to
            # what generates it instead, in a `<name>-persist.nix` sibling of
            # the module that owns the state:
            #
            #   desktop-env/jovian/jovian-persist.nix     /etc/hhd
            #   system/networking/tailscale-persist.nix   /var/lib/tailscale
            #
            # Filing them as siblings is what scopes them: each is collected by
            # the same category as the module it belongs to, so /etc/hhd
            # persists only on hosts that actually run handheld-daemon.
            # `directories` is `listOf`, so entries from every file concatenate.
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

            # impermanence-style wiping root results in sudo lectures after each reboot
            security.sudo.extraConfig = ''
                Defaults lecture = never
            '';
            # Hibernation is disabled, and on a host that wipes /root it has to
            # be: a hibernation image is a snapshot of a system whose /root
            # existed, and resuming it after the rollback has deleted and
            # recreated that subvolume restores a kernel holding open files
            # that are gone.
            #
            # Nothing in this config asks for hibernation, and it still had a
            # live target on tenacity (2026-08-10): systemd-gpt-auto-generator
            # finds swap partitions by GPT type UUID, activates them with no
            # configuration at all, and sets the resume device to match --
            # /proc/swaps showed nvme0n1p6 active and /sys/power/resume pointed
            # at it, with no `resume=` anywhere and `swapDevices = []`. Read
            # the machine, not the config (lessons-learned §2, §24).
            #
            # It surfaced as "suspend hangs with the fan on": KDE asked for
            # hybrid-sleep -- suspend *plus* writing a hibernation image -- and
            # systemd-hybrid-sleep.service spent ~19s of wall clock and ~2.3G
            # of writes. That hang is NOT a regression from the stage-1
            # migration (the journal shows the same behaviour under scripted
            # stage 1); what the migration DID change is the guard.
            # `postResumeCommands` ran *after* the resume attempt, so a
            # successful resume skipped the wipe by construction;
            # restore-root.service has no such ordering and can race ahead of
            # a resuming boot, deleting the /root the restored image expects.
            # Reachable on a handheld specifically: a flat battery during
            # suspend is exactly the case that resumes from disk. It has never
            # fired -- but it was one dead battery away.
            #
            # REQUIRES A MATCHING CHANGE IN KDE. `~/.config/powerdevil.rc` must
            # have `SleepMode=1` -- PowerDevil's enum is
            # `SuspendToRam = 1, HybridSuspend = 2, SuspendThenHibernate = 3`
            # (plasma/powerdevil, daemon/powerdevilenums.h), and it was set to
            # 2. Nothing falls back: PowerDevil asks logind for HybridSleep,
            # logind answers CanHybridSleep=no, and the request is simply
            # dropped, so suspend stops working entirely until the KDE setting
            # changes. An earlier version of this comment claimed disabling
            # hibernation would degrade such a request to plain s2idle; it does
            # not. logind still reports CanSuspend=yes and /sys/power/state
            # still offers `freeze mem` throughout -- only the request was
            # gone. s2idle is the only mem_sleep this hardware advertises
            # anyway (/sys/power/mem_sleep is `[s2idle]`, no `deep`).
            #
            # nohibernate is the kernel-level switch, so it holds regardless of
            # what systemd discovers; the sleep.conf entries are so logind and
            # powerdevil stop offering the options rather than failing them.
            #
            # settings.Sleep, not extraConfig: `systemd.sleep.extraConfig` was
            # removed in 26.11 and errors out by name rather than being ignored.
            boot.kernelParams = [ "nohibernate" ];
            systemd.sleep.settings.Sleep = {
                AllowHibernation          = false;
                AllowHybridSleep          = false;
                AllowSuspendThenHibernate = false;
            };

            # reset / at each boot, under systemd stage 1
            boot.initrd = {
                enable = true;
                supportedFilesystems = [ "btrfs" ];

                # Migrated from boot.initrd.postResumeCommands on 2026-08-10.
                #
                # The 2026-08-07 nixpkgs flipped boot.initrd.systemd.enable to
                # default true and warns "Scripted initrd is deprecated and
                # scheduled for removal in 26.11" -- and the same bump moved
                # both hosts to 26.11. postResumeCommands is a scripted stage-1
                # mechanism which systemd stage 1 rejects with a failed
                # assertion, so the two cannot overlap and the switch is atomic.
                #
                # Not to be confused with boot.loader.systemd-boot, which both
                # hosts also set. That is the EFI bootloader; this is systemd
                # inside the initramfs. Similar names, unrelated options -- and
                # the likeliest reason ad38ffb's first attempt looked finished.
                #
                # The working note, wiki/impermanence-stage1-migration.md,
                # was removed 2026-09-05 -- git history has it.
                systemd = {
                    enable = true;

                    # emergencyAccess is deliberately NOT set -- the default
                    # (false) is what we want. `true` means an
                    # *unauthenticated* root shell from emergency.target,
                    # which under systemd stage 1 can be reached before the
                    # LUKS volume is open: a root shell for anyone holding the
                    # handheld. It was carried for exactly one boot, to make
                    # the first-ever boot of this branch debuggable (see
                    # history).
                    #
                    # OnFailure = emergency.target below still does its job
                    # without it: the point was never the shell, it was
                    # stopping a failed rollback from being a failed unit
                    # nothing depends on, with the boot carrying on and /root
                    # quietly un-wiped. The prompt is unenterable anyway --
                    # root has no password on either host
                    # (users.mutableUsers = false; only elly has a
                    # hashedPasswordFile). Recovery picks the previous
                    # generation in the systemd-boot menu -- the same
                    # recovery step this repo has always pointed at. If an
                    # initrd shell is ever genuinely needed, set this to a
                    # password hash rather
                    # than `true` -- the option takes
                    # `oneOf [ bool (nullOr (passwdEntry str)) ]`, so
                    # authenticated access is available without reopening the
                    # unauthenticated hole.

                    services.restore-root = {
                        description = "Roll /root back to the blank btrfs snapshot";

                        # initrd-root-device.target is the host-generic
                        # synchronisation point: reached once the root block
                        # device exists, after LUKS unlock, whatever the volume
                        # is called. It also replaces the scripted version's
                        # `udevadm settle`: rootDevice is a /dev/disk/by-uuid
                        # path, that symlink is udev's work, and a systemd
                        # .device unit only becomes active once udev has
                        # finished with the device -- so ordering after these
                        # is a real barrier, not the poll it replaces.
                        #
                        # Requires= and After= are independent -- activation
                        # dependency versus pure ordering -- and systemd.unit(5)
                        # says to pair them. Requires= alone can run before the
                        # device exists; After= alone runs the service anyway
                        # and lets it fail.
                        wantedBy = [ "initrd.target" ];
                        requires = luksDeviceUnits;
                        after    = [ "initrd-root-device.target" ] ++ luksDeviceUnits ++ luksCryptUnits;
                        before   = [ "sysroot.mount" ];

                        unitConfig = {
                            DefaultDependencies = "no";

                            # The safety property postResumeCommands gave for
                            # free, and the one thing this conversion would
                            # otherwise silently drop: that option ran *after*
                            # the resume attempt, so a successful resume
                            # skipped the wipe. A plain initrd.target unit has
                            # no equivalent and would delete the root the
                            # restored memory image expects. Fails in the safe
                            # direction -- stops wiping rather than wiping a
                            # resuming system.
                            #
                            # NOT the real defence, and on its own it does not
                            # work here: it keys on a kernel command line
                            # parameter, and systemd does not need one. On
                            # tenacity (2026-08-10) /sys/power/resume was
                            # already 259:6 -- nvme0n1p6 -- with no `resume=`
                            # anywhere, because systemd-gpt-auto-generator
                            # discovered the swap partition by GPT type and
                            # wired it up. This condition would have passed and
                            # the wipe gone ahead. `nohibernate` above is what
                            # actually closes it; this stays as a second line
                            # only.
                            ConditionKernelCommandLine = [ "!resume" ];

                            # Otherwise a failed rollback is just a failed unit
                            # that nothing depends on: the boot carries on with
                            # /root un-wiped, which looks exactly like a working
                            # system until the disk fills.
                            OnFailure = "emergency.target";
                        };

                        serviceConfig.Type = "oneshot";

                        # Runs under `set -e` -- the opposite of the scripted
                        # stage-1 code it replaced, where a failed mount left
                        # every later command failing harmlessly against an
                        # empty /mnt and the rollback silently not happening
                        # (nixpkgs builds job scripts with makeJobScript,
                        # writeShellScriptBin over `set -e` --
                        # nixos/lib/systemd-lib.nix). The first failure now
                        # aborts the unit and OnFailure turns it into
                        # emergency. The tools are all present: btrfs because
                        # boot.initrd.supportedFilesystems includes btrfs;
                        # mount/umount from systemd's own extraBin; coreutils,
                        # for cut, from initrdBin. PATH in the initrd is
                        # /bin:/sbin.
                        script = ''
                            mkdir -p /mnt

                            # Mount the btrfs top level to /mnt so we can
                            # manipulate subvolumes. ${rootDevice} rather than
                            # a hardcoded /dev/mapper/enc: taken from this
                            # host's own fileSystems, so the module carries no
                            # host-specific device name.
                            mount -o subvol=/ ${rootDevice} /mnt

                            # /root is already populated with nested subvolumes
                            # at this point, which makes `btrfs subvolume
                            # delete` fail, so remove them first. Observed on
                            # the machine 2026-08-10: srv, var/lib/portables,
                            # var/lib/machines, var/tmp -- the middle two
                            # probably systemd-nspawn-related, unused here.
                            # Deleting them has caused no issues beyond
                            # benign-looking systemd-tmpfiles errors.
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

                            # Once we're done rolling back to a blank snapshot,
                            # we can unmount /mnt and continue on the boot process.
                            umount /mnt
                        '';
                    };
                };
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-10 — the stage-1 migration (ad38ffb) took three scripted-stage-1
# behaviours with it; recorded because a revert would bring the mechanism
# back.
#
# - `udevadm settle` guarded the mount: the scripted initrd hardcoded
#   /dev/mapper/enc (created synchronously by cryptsetup), while
#   fileSystems."/" is a by-uuid path udev creates asynchronously — the
#   rollback raced udev, and losing the race was a silent non-wipe. After=
#   the device units above fixes it structurally.
# - `boot.kernelParams = [ "boot.shell_on_fail" ]` was what made
#   stage-1-init.sh's fail() offer an interactive shell; OnFailure=
#   emergency.target above is the systemd equivalent.
# - The `if ! mount ...; then fail; fi` guards died with `set -e`: systemd
#   job scripts (makeJobScript) abort on first failure, so OnFailure= fires.
#
# emergencyAccess = true was carried for the first boot of this branch
# (debugging a systemd stage-1 failure pre-LUKS needs an unauthenticated
# shell — a knowingly-accepted hole) and removed 2026-08-10 once the
# rollback was confirmed by subvolid.
#
# The scripted-stage-1 template-injection trap — never write an
# @placeholder@ token inside a scripted hook string, comments included;
# 19 substituteInPlace passes assemble stage-1-init.sh and a later pass
# expands it — died with the mechanism. Full account: skill
# `impermanence-initrd`.
#
# 2026-08-09 — the commented-out fileSystems block: this module and the
# host hardware configs both declared mount options, and `options` is
# `listOf str`, so the definitions concatenated (every option twice —
# harmless to mount, but the one-owning-module rule broken). The hardware
# config owns them: it knows the subvol names. Nothing was lost — the
# option *set* verified unchanged with `just diff`. Before re-enabling any
# line above, check what the host hwconfig already declares for that mount.
#
# 2026-08-09 — the ordering fix in ad38ffb: the old unit hardcoded
# `requires = [ "dev-mapper-enc.device" ]`, `after = [ "dev-mapper-enc.device"
# "systemd-cryptsetup@nire-durandal.service" ]`, and mounted /dev/mapper/enc.
# The crypt unit is named after the *volume*, not the host (luksroot.nix,
# stage1Crypttab), so systemd-cryptsetup@nire-durandal.service never existed
# anywhere — the After= was a silent no-op (dev-mapper-enc.device beside it
# was what actually ordered things), and interpolating networking.hostName
# would have been wrong the same way on tenacity. Deriving from
# boot.initrd.luks.devices above fixed it; durandal's generated values came
# out byte-identical (`just diff`).
#
# 2026-08-10 — the hibernation hazard closed by nohibernate and the
# ConditionKernelCommandLine notes above also came from ad38ffb:
# postResumeCommands ran after the resume attempt, so a successful
# hibernation resume skipped the wipe. The wrong assessment that started it
# ("tenacity has no swap") and the full story: lessons-learned §28.
