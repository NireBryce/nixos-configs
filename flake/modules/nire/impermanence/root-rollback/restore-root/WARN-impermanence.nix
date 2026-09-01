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
                # claude cave/lessons-learned-impermanence-stage1-migration.md is the working note.
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
# 2026-08-10 — what the move to systemd stage 1 took out with it
#
# Three things were true only of scripted stage 1; recorded because the
# mechanism could come back if the migration is ever reverted.
#
# `udevadm settle` before the mount. The deployed initrd hardcoded
# /dev/mapper/enc, which cryptsetup creates synchronously; fileSystems."/".device
# is a /dev/disk/by-uuid path, and udev creates that symlink asynchronously,
# with no settle or waitDevice between the LUKS open and postResumeCommands.
# The rollback raced udev; losing the race meant a failed mount and a wipe
# that silently did not happen. The systemd unit fixes this structurally:
# After= the device units means udev has finished with the device by
# definition.
#
# `boot.kernelParams = [ "boot.shell_on_fail" ]`, and the `fail` calls that
# needed it. stage-1-init.sh defines fail(), but it only offers an interactive
# shell when `allowShell` is set, and that comes from that kernel parameter.
# Without it fail() still prompts and blocks on `read -n 1`, but the only
# choices are `r` to reboot or any other key to continue. The systemd
# equivalent is OnFailure=emergency.target, still set above.
#
#
# 2026-08-10 (later the same day) — emergencyAccess, set and then removed
#
# The migration carried `boot.initrd.systemd.emergencyAccess = true` so the
# first-ever boot of this branch was debuggable -- systemd stage 1, a
# rewritten rollback and a nixpkgs release jump all landed together, and a
# failure would have needed inspecting from inside the initrd. `true` makes
# OnFailure=emergency.target's password prompt unauthenticated, and under
# systemd stage 1 that prompt is reachable *before* the LUKS volume is open,
# so "whoever reaches it already typed the passphrase" stops being true: a
# real hole, accepted knowingly, for exactly one boot. Removed once the
# rollback was confirmed by subvolid. Nothing depended on it -- the value of
# OnFailure is halting the boot, not the shell; recovery is picking the
# previous generation in the boot menu. If an initrd shell is ever genuinely
# needed, set the option to a password hash (`oneOf [ bool (nullOr
# (passwdEntry str)) ]`), strictly better than what was here.
#
# The explicit `if ! mount ...; then ... fail; fi` guards: with no `set -e`
# in stage-1-init.sh, a failed mount left every later command failing
# harmlessly against an empty /mnt -- looking exactly like a working system
# until the disk fills. systemd job scripts (makeJobScript, writeShellScriptBin
# over `set -e`) abort on first failure, so the guards were redundant; see
# above.
#
# One trap that died with the mechanism, kept because it cost a near-miss:
# never write an at-sign placeholder token inside a scripted stage-1 hook
# string, comments included. stage-1-init.sh is assembled by 19 sequential
# substituteInPlace --replace-fail passes and the one pasting postResumeCommands
# in runs 10th, so any such token survives insertion and is expanded by a later
# pass -- naming the pre-LVM hook in a comment would have pasted the whole LUKS
# unlock script into the comment, only its first line commented out. Full
# account: AGENTS.md, skill `impermanence-initrd`.
#
#
# 2026-08-09 — why the fileSystems block at the top is commented out
#
# This module and each host's hardware-configuration.nix both declared mount
# options for /, /home, /nix, /persist and /var/log, and
# `fileSystems.<n>.options` is `listOf str` -- the definitions concatenated,
# every option appearing twice (e.g. /: "compress=zstd" "noatime" doubled).
# Harmless in practice -- mount accepts a repeated option, last wins -- but
# it is the one-owning-module rule broken, the same way `.blerc` and
# `home.sessionPath` were; the hardware config knows the subvol names, so it
# owns the options too. Nothing was lost: every option above, and
# `neededForBoot` for /persist and /var/log, was already declared in the
# hwconfigs -- verified with `just diff`, option *set* unchanged, only the
# repeats gone.
#
# If you re-enable any of these, check what the host hwconfig already declares
# for that mount first.
#
#
# 2026-08-09 — restore-root's ordering, and the unit that never existed
#
# The dependencies were, verbatim: `requires = [ "dev-mapper-enc.device" ]`;
# `after = [ "dev-mapper-enc.device" "systemd-cryptsetup@nire-durandal.service" ]`
# (with a `#TODO: fix me to be general`); and the script mounted a hardcoded
# `/dev/mapper/enc`.
#
# `systemd-cryptsetup@nire-durandal.service` is not a unit that exists. systemd
# names the unit after the *volume*, not the host: nixpkgs writes
# boot.initrd.luks.devices.<n> as field 1 of the initrd crypttab
# (luksroot.nix, stage1Crypttab), and systemd-cryptsetup-generator derives
# systemd-cryptsetup@<that field>.service from it. Both machines set
# boot.initrd.luks.devices."enc", so the real unit is
# systemd-cryptsetup@enc.service on each -- the After= line had been doing
# nothing at all, a silent no-op on durandal as much as anywhere; what held
# the ordering was dev-mapper-enc.device beside it.
#
# All three are now derived from boot.initrd.luks.devices and fileSystems."/",
# so nothing names a host or assumes a mapper name; both machines use `enc`,
# so durandal's generated values are unchanged -- confirmed with `just diff`,
# byte-identical toplevel. Interpolating networking.hostName instead would
# have been wrong the same way: systemd-cryptsetup@nire-tenacity.service on
# the second host, a second nonexistent unit, a second silent no-op.
#
#
# 2026-08-10 — hibernation: outstanding, then resolved
#
# `boot.initrd.postResumeCommands`, which ad38ffb replaced with this service,
# ran *after* the resume attempt, so a successful hibernation resume skipped
# the wipe; this service has no equivalent guard. RESOLVED 2026-08-10 by
# `boot.kernelParams = [ "nohibernate" ]` above. The assessment that stood
# here first is kept because the way it was wrong is the point:
#
#   "Neither host puts `resume` on the kernel command line today -- durandal has
#    a swap device but no boot.resumeDevice, tenacity has no swap -- so nothing
#    is wrong now."
#
# Two errors in one sentence, both from reading the config instead of the
# machine, and both written into the module that deletes /root:
#
# 1. Tenacity has 20G of swap on nvme0n1p6, plus zram. `swapDevices = [ ]` in
#    hardware-tenacity.nix describes what the config declares, not what the
#    machine runs -- systemd-gpt-auto-generator activates the partition on its
#    own, by GPT type UUID.
# 2. "No `resume=` on the kernel command line" was true and irrelevant.
#    /sys/power/resume was already set to 259:6 anyway, because systemd does not
#    need the parameter. So ConditionKernelCommandLine = [ "!resume" ], added as
#    the fix for this very note, would have passed and let the wipe proceed.
#
# lessons-learned.md §2 ("the repo is not the machine") and §24 ("compare
# against what is deployed"), both demonstrated here.
