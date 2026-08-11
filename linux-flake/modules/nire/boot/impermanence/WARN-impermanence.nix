{ lib, inputs, ... }:
    let
        # As everywhere here, the attribute name comes from the filename: rename
        # WARN-impermanence.nix and this silently becomes
        # flake.modules.nixos.<newname>. Category membership survives that,
        # because dirsAsCategory looks its members up by filename too and the
        # two move together -- but it is worth knowing for a module that deletes
        # /root, since anything importing it by literal name is what would break.
        # See CLAUDE.md, "A module's name is its filename".
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, ... }:
        let
            # The filesystem holding the root subvolume. The script mounts its
            # btrfs top level to reach the subvolumes; taking it from fileSystems
            # stays unambiguous even if a host ever unlocks more than one volume.
            rootDevice = config.fileSystems."/".device;

            # Ordering for the rollback unit. systemd names the crypt unit after
            # the *volume*, not the host: nixpkgs writes
            # boot.initrd.luks.devices.<n> as field 1 of the initrd crypttab
            # (luksroot.nix, stage1Crypttab -- `"${n} ${v.device} ..."`) and
            # systemd-cryptsetup-generator derives
            # systemd-cryptsetup@<that field>.service from it.
            #
            # Both machines use "enc", so deriving these costs nothing today. It
            # stops the next host from ordering against a unit that is never
            # generated, which is exactly what ad38ffb did with
            # systemd-cryptsetup@nire-durandal.service -- and After= a
            # non-existent unit is a silent no-op, not an error.
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

            imports = [
                inputs.impermanence.nixosModule
            ];
            # impermanence
            environment.etc.machine-id.source = "/persist/etc/machine-id";

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
            security.sudo.extraConfig = ''
                # impermanence-style wiping root results in sudo lectures after each reboot
                Defaults lecture = never
            '';
            # Hibernation is disabled, and on a host that wipes /root it has to
            # be. A hibernation image is a snapshot of a system whose /root
            # existed; resuming it after the rollback has deleted and recreated
            # that subvolume restores a kernel holding open files that are gone.
            #
            # This is not theoretical here, which was the surprise. Nothing in
            # this config asks for hibernation -- boot.resumeDevice is "" and
            # swapDevices is [] on both hosts -- but on tenacity, 2026-08-10:
            #
            #   /proc/swaps          /dev/nvme0n1p6, 20G, active
            #   /sys/power/resume    259:6, i.e. that same partition
            #   the unit             dev-disk-by\x2ddesignator-swap.swap
            #
            # systemd-gpt-auto-generator finds swap partitions by GPT type UUID
            # and activates them with no configuration at all, and sets the
            # resume device to match. So hibernation had a live target that
            # nobody chose.
            #
            # It surfaced as "suspend hangs with the fan on": KDE asked for
            # hybrid-sleep, which is suspend *plus* writing a hibernation image,
            # and systemd-hybrid-sleep.service spent 19 seconds of wall clock and
            # 2.3G of writes before coming back. Disabling hibernation makes any
            # such request fall back to a plain s2idle suspend, which is the only
            # sleep state this hardware advertises anyway (/sys/power/mem_sleep is
            # `[s2idle]`, with no `deep`).
            #
            # That hang is NOT a regression from the stage-1 migration, and the
            # first version of this comment implied it was. The journal covers a
            # boot that ran from 2025-12-17 to 2026-08-10 under scripted stage 1,
            # and hybrid-sleep behaves the same there: 14.8s/2.1G, 15.2s/2.2G,
            # 20.4s/2.1G, against 19.0s/2.3G and 12.9s/2.0G afterwards. This
            # machine has been writing hibernation images for months.
            #
            # What the migration DID change is the guard, and that is the part
            # that matters. `postResumeCommands` ran *after* the kernel's resume
            # attempt -- the safety was in the name -- so a successful resume
            # skipped the wipe by construction. restore-root.service has no such
            # ordering, so on a boot that resumes from disk it can race ahead of
            # the resume and delete the /root the restored image expects.
            #
            # Which is reachable on this hardware specifically: it is a handheld,
            # every suspend leaves a hibernation image on nvme0n1p6, and a flat
            # battery during suspend is exactly the case that resumes from disk
            # rather than from RAM. It appears never to have fired -- that
            # eight-month boot resumed from RAM every time -- but it was one dead
            # battery away.
            #
            # nohibernate is the kernel-level switch, so it holds regardless of
            # what systemd discovers. The sleep.conf entries are so that logind
            # and powerdevil stop offering the options rather than failing them.
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
                # linux-flake/impermanence-stage1.md is the working note.
                systemd = {
                    enable = true;

                    # emergencyAccess is deliberately NOT set -- the default is
                    # false, which is what we want. See the history block; it
                    # was true for exactly one boot.
                    #
                    # `true` means an *unauthenticated* root shell from
                    # emergency.target, which under systemd stage 1 can be
                    # reached before the LUKS volume is open. That is a root
                    # shell for anyone holding the handheld, and it was carried
                    # only to make the first-ever boot of this branch
                    # debuggable.
                    #
                    # OnFailure = emergency.target below still does its job
                    # without it. The point of that line was never the shell --
                    # it was to stop a failed rollback from being a failed unit
                    # nothing depends on, with the boot carrying on and /root
                    # quietly un-wiped. It still halts the boot loudly. The
                    # prompt is simply unenterable, because root has no password
                    # on either host (users.mutableUsers = false, and only elly
                    # has a hashedPasswordFile).
                    #
                    # Recovery does not need that shell: pick the previous
                    # generation in the systemd-boot menu, which is what the
                    # runbook says to do anyway. If a future failure genuinely
                    # needs an initrd shell, set this to a password hash rather
                    # than `true` -- the option takes `oneOf [ bool (nullOr
                    # (passwdEntry str)) ]`, so authenticated access is
                    # available without reopening the unauthenticated hole.

                    services.restore-root = {
                        description = "Roll /root back to the blank btrfs snapshot";

                        # initrd-root-device.target is the host-generic
                        # synchronisation point: reached once the root block
                        # device exists, after LUKS unlock, whatever the volume
                        # is called.
                        #
                        # It also removes the reason the scripted version needed
                        # `udevadm settle`. rootDevice is a /dev/disk/by-uuid
                        # path on both hosts and that symlink is udev's work; a
                        # systemd .device unit only becomes active once udev has
                        # finished with the device, so ordering after these is a
                        # real barrier rather than the poll it replaces.
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
                            # the resume attempt, so a successful hibernation
                            # resume skipped the wipe. A plain initrd.target
                            # unit has no equivalent and would delete the root
                            # that the restored memory image expects.
                            #
                            # Fails in the safe direction -- stops wiping rather
                            # than wiping a resuming system.
                            #
                            # It is NOT the real defence, and on its own it does
                            # not work here: it keys on a kernel command line
                            # parameter, and systemd does not need one. On
                            # tenacity, 2026-08-10, /sys/power/resume was already
                            # 259:6 -- nvme0n1p6 -- with no `resume=` anywhere,
                            # because systemd-gpt-auto-generator discovered the
                            # swap partition by GPT type and wired it up. So this
                            # condition would have passed and the wipe would have
                            # gone ahead. `nohibernate` below is what actually
                            # closes it; this stays as a second line only.
                            ConditionKernelCommandLine = [ "!resume" ];

                            # Otherwise a failed rollback is just a failed unit
                            # that nothing depends on: the boot carries on with
                            # /root un-wiped, which looks exactly like a working
                            # system until the disk fills.
                            OnFailure = "emergency.target";
                        };

                        serviceConfig.Type = "oneshot";

                        # This script runs under `set -e`, which is the opposite
                        # of the scripted stage-1 situation it replaces.
                        # nixpkgs builds service scripts with makeJobScript,
                        # which is writeShellScriptBin over `set -e`
                        # (nixos/lib/systemd-lib.nix). Under stage-1-init.sh
                        # there was no errexit, so every command after a failed
                        # mount failed harmlessly against an empty /mnt and the
                        # rollback just stopped happening. Here the first
                        # failure aborts the unit and OnFailure turns it into
                        # emergency, so the explicit guards that used to be
                        # necessary are not.
                        #
                        # The tools are all present: btrfs because
                        # boot.initrd.supportedFilesystems includes btrfs and
                        # tasks/filesystems/btrfs.nix feeds
                        # boot.initrd.systemd.initrdBin from it; mount and
                        # umount from systemd's own extraBin; coreutils, for
                        # cut, from initrdBin. PATH in the initrd is /bin:/sbin.
                        script = ''
                            mkdir -p /mnt

                            # We first mount the btrfs root to /mnt
                            # so we can manipulate btrfs subvolumes.
                            #
                            # ${rootDevice} rather than a hardcoded
                            # /dev/mapper/enc: taken from this host's own
                            # fileSystems, so the module carries no
                            # host-specific device name.
                            mount -o subvol=/ ${rootDevice} /mnt

                            # While we're tempted to just delete /root and create
                            # a new snapshot from /root-blank, /root is already
                            # populated at this point with a number of subvolumes,
                            # which makes `btrfs subvolume delete` fail.
                            # So, we remove them first.
                            #
                            # /root contains subvolumes:
                            # - /root/var/lib/portables
                            # - /root/var/lib/machines
                            #
                            # I suspect these are related to systemd-nspawn, but
                            # since I don't use it I'm not 100% sure.
                            # Anyhow, deleting these subvolumes hasn't resulted
                            # in any issues so far, except for fairly
                            # benign-looking errors from systemd-tmpfiles.
                            #
                            # Read off the running machine on 2026-08-10, the
                            # list was srv, var/lib/portables, var/lib/machines
                            # and var/tmp -- so `srv` and `var/tmp` join the two
                            # named above.
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
# Three things above were true only of scripted stage 1 and are recorded here
# rather than deleted, because each is a real finding and the mechanism could
# come back if the migration is ever reverted.
#
# `udevadm settle` before the mount. The deployed system's initrd hardcoded
# /dev/mapper/enc, which cryptsetup creates synchronously. fileSystems."/".device
# is a /dev/disk/by-uuid path on both hosts, and that symlink is created
# asynchronously by udev afterwards -- with no `udevadm settle` and no
# `waitDevice` anywhere between the LUKS open and postResumeCommands. The next
# settle in stage-1-init.sh ran after the whole block. So the rollback raced
# udev, and losing the race meant a mount that failed and a wipe that silently
# did not happen. The systemd unit fixes this structurally instead: ordering
# After= the device units means udev has finished with the device by
# definition, so no polling is involved.
#
# `boot.kernelParams = [ "boot.shell_on_fail" ]`, and the `fail` calls that
# needed it. stage-1-init.sh defines fail(), but it only offers an interactive
# shell when `allowShell` is set, and that comes from that kernel parameter.
# Without it fail() still prompts and still blocks on `read -n 1`, but the only
# choices are `r` to reboot or any other key to continue. The systemd
# equivalent is OnFailure=emergency.target, still set above.
#
#
# 2026-08-10 (later the same day) — emergencyAccess, set and then removed
#
# The migration also carried `boot.initrd.systemd.emergencyAccess = true`,
# because OnFailure=emergency.target drops to a prompt that asks for the root
# password and root has no password on either host, so the prompt is
# unenterable. `true` makes that access unauthenticated.
#
# That was a real hole and it was accepted knowingly, to make the first-ever
# boot of this branch debuggable: systemd stage 1, a rewritten rollback and a
# nixpkgs release jump all landed together, and a failure would have needed
# inspecting from inside the initrd. Under systemd stage 1 the exposure is also
# worse than the scripted equivalent it replaced -- stage 1 can fail *before*
# the LUKS volume is open, so "whoever reaches this prompt already typed the
# passphrase" stops being true.
#
# Removed once the branch booted and the rollback was confirmed by subvolid.
# Nothing depended on it: the value of OnFailure is halting the boot, not the
# shell, and recovery is picking the previous generation in the boot menu.
#
# If an initrd shell is ever genuinely needed again, set the option to a
# password hash instead of `true`. Its type is
# `oneOf [ bool (nullOr (passwdEntry str)) ]`, so authenticated emergency
# access exists and is strictly better than what was here.
#
# The explicit `if ! mount ...; then ... fail; fi` guards. There is no `set -e`
# in stage-1-init.sh, so after a failed mount every later command failed
# harmlessly against an empty /mnt and the rollback simply stopped happening --
# which looks exactly like a working system until the disk fills. systemd job
# scripts are built by makeJobScript, which is writeShellScriptBin over
# `set -e`, so the first failure now aborts the unit on its own and the guards
# were dropped as redundant.
#
# One trap that died with the mechanism, kept because it cost a near-miss:
# never write an at-sign placeholder token inside a scripted stage-1 hook
# string, comments included. stage-1-init.sh is assembled by 19 sequential
# substituteInPlace --replace-fail passes and the one pasting postResumeCommands
# in runs 10th, so any such token survives insertion and is then expanded by a
# later pass. Naming the pre-LVM hook in a comment would have pasted the whole
# LUKS unlock script into the middle of that comment, where only its first line
# stays commented out. Full account in CLAUDE.md.
#
#
# 2026-08-09 — why the fileSystems block at the top is commented out
#
# This module declared mount options for /, /home, /nix, /persist and /var/log,
# and so did each host's hardware-configuration.nix. `fileSystems.<n>.options`
# is `listOf str`, so those definitions did not override one another — they
# concatenated. Durandal evaluated to:
#
#   /          [ "x-initrd.mount" "subvol=root" "compress=zstd" "noatime"
#                                               "compress=zstd" "noatime" ]
#   /home      [ "subvol=home" "compress=zstd" "compress=zstd" ]
#   /nix       [ "x-initrd.mount" "subvol=nix" "compress=zstd" "noatime"
#                                              "compress=zstd" "noatime" ]
#   /persist   ... same doubling
#   /var/log   ... same doubling
#
# Harmless in practice — mount accepts a repeated option and the last wins —
# but it is the one-owning-module rule broken, the same way `.blerc` and
# `home.sessionPath` were. The hardware config is the owner that has to know the
# subvol names anyway, so it owns the rest too.
#
# Nothing is lost: every option above, and `neededForBoot` for /persist and
# /var/log, is declared in the hwconfigs already. Verified after the change with
# `just diff` — the option *set* per filesystem is unchanged, only the repeats
# are gone.
#
# If you re-enable any of these, check what the host hwconfig already declares
# for that mount first.
#
#
# 2026-08-09 — restore-root's ordering, and the unit that never existed
#
# The dependencies were, verbatim:
#
#   requires = [
#       "dev-mapper-enc.device" # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
#   ];
#   after = [
#       "dev-mapper-enc.device" # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
#       "systemd-cryptsetup@nire-durandal.service"
#   ];#TODO: fix me to be general this is just to make it work for now
#
#   ...and the script mounted a hardcoded `/dev/mapper/enc`.
#
# `systemd-cryptsetup@nire-durandal.service` is not a unit that exists. systemd
# names the unit after the *volume*, not the host: nixpkgs writes
# boot.initrd.luks.devices.<n> as field 1 of the initrd crypttab
# (luksroot.nix, stage1Crypttab -- `"${n} ${v.device} ..."`), and
# systemd-cryptsetup-generator derives systemd-cryptsetup@<that field>.service
# from it. Both machines set boot.initrd.luks.devices."enc", so the real unit is
# systemd-cryptsetup@enc.service on each.
#
# Ordering After= a unit that is never generated is a silent no-op, so that line
# had been doing nothing at all -- on durandal as much as anywhere. What actually
# held the ordering was dev-mapper-enc.device beside it.
#
# All three are now derived from boot.initrd.luks.devices and fileSystems."/", so
# nothing here names a host or assumes a mapper name. Both machines happen to use
# `enc`, so the generated values are unchanged for durandal -- confirmed with
# `just diff`, byte-identical toplevel.
#
# Why this was worth doing rather than interpolating the hostname: the hostname
# was never the right value. Substituting networking.hostName would have produced
# systemd-cryptsetup@nire-tenacity.service on the second host -- a second unit
# that does not exist, and a second silent no-op.
#
#
# STILL OUTSTANDING — hibernation
#
# `boot.initrd.postResumeCommands`, which ad38ffb replaced with this service, had
# a safety property in its name: it ran *after* the resume attempt, so a
# successful hibernation resume skipped the wipe. This service has no equivalent
# guard, so if a resume ever happens it will delete the root the restored memory
# image expects.
#
# RESOLVED 2026-08-10 by `boot.kernelParams = [ "nohibernate" ]` above. The
# paragraph that stood here is kept because the way it was wrong is the point:
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
# lessons.md §2 is "the repo is not the machine" and §24 is "compare against what
# is deployed". This is both of them, committed the same day, by the person who
# wrote them down.
