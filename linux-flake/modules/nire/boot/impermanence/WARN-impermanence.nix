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
            # Required by the `fail` calls in postResumeCommands below.
            #
            # stage-1-init.sh's fail() only offers an interactive shell when
            # `allowShell` is set, and that comes from this kernel parameter.
            # Without it fail() still prompts -- and blocks on `read -n 1` --
            # but the only options are `r` to reboot or any other key to
            # continue, which is precisely the silent-continue this is meant to
            # stop. Not `boot.panic_on_fail`: that exits stage 1 outright, with
            # no chance to look at why.
            #
            # Modest security cost, and it is bounded: everything here runs
            # *after* the LUKS volume is open, so anyone who can reach this
            # prompt already had the passphrase.
            boot.kernelParams = [ "boot.shell_on_fail" ];

            # reset / at each boot
            boot.initrd = {
                enable = true;
                supportedFilesystems = [ "btrfs" ];

                # postResumeCommands, not a boot.initrd.systemd.services unit.
                # Both hosts run the *scripted* stage 1 -- boot.initrd.systemd.enable
                # is false, and in 26.05 that is still an mkEnableOption defaulting
                # off; boot.loader.systemd-boot is the EFI bootloader and a
                # different thing entirely. A systemd-initrd unit is simply not
                # rendered under scripted stage 1, so the service this replaces was
                # never built into the initrd at all. See the history block.
                #
                # This option is rejected *only* when systemd stage 1 is enabled
                # (nixos/modules/system/boot/systemd/initrd.nix lists it among the
                # unsupported ones), so it is correct here and will need revisiting
                # if stage 1 is ever turned on.
                #
                # https://github.com/NixOS/nixpkgs/pull/240651
                postResumeCommands = lib.mkAfter ''
                    mkdir -p /mnt

                    # We first mount the btrfs root to /mnt
                    # so we can manipulate btrfs subvolumes.
                    #
                    # ${rootDevice} rather than a hardcoded /dev/mapper/enc: taken
                    # from this host's own fileSystems, so the module carries no
                    # host-specific device name.
                    #
                    # udevadm settle, because that swap has a cost. The deployed
                    # system named /dev/mapper/enc, which cryptsetup creates
                    # synchronously; fileSystems."/".device is a
                    # /dev/disk/by-uuid path on BOTH hosts, and that symlink is
                    # created asynchronously by udev afterwards. Nothing between
                    # the LUKS open and this point synchronises -- the next
                    # udevadm settle in stage-1-init.sh runs after this whole
                    # block. udevd is still running here; it is not stopped
                    # until `udevadm control --exit`, much later.
                    #
                    # NOTE: do not write an at-sign placeholder name in this
                    # string. stage-1-init.sh is assembled by a series of
                    # substituteInPlace --replace-fail passes, and the one that
                    # pastes this block in runs 10th of 19 -- so any such token
                    # left in here is substituted by a LATER pass. Naming the
                    # pre-LVM one in a comment would have pasted the entire LUKS
                    # unlock script into the middle of that comment, where only
                    # its first line stays commented out.
                    udevadm settle

                    # Fail loudly. Every command after a failed mount would
                    # otherwise fail harmlessly against an empty /mnt -- there is
                    # no `set -e` in stage-1-init.sh -- so the rollback would
                    # simply stop happening, and a machine that has silently
                    # stopped wiping /root looks exactly like a working one until
                    # the disk fills.
                    if ! mount -o subvol=/ ${rootDevice} /mnt; then
                        echo "impermanence: could not mount the btrfs top level of ${rootDevice}"
                        echo "impermanence: /root has NOT been rolled back this boot"
                        fail
                    fi

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
                    btrfs subvolume list -o /mnt/root |
                    cut -f9 -d' ' |
                    while read subvolume; do
                    echo "deleting /$subvolume subvolume..."
                    btrfs subvolume delete "/mnt/$subvolume"
                    done &&
                    echo "deleting /root subvolume..." &&
                    btrfs subvolume delete /mnt/root

                    # The one choke point worth guarding besides the mount. It
                    # catches the delete above failing too: a /root that could
                    # not be deleted still exists, so the snapshot cannot be
                    # created over it. It also catches root-blank being absent,
                    # which is the prerequisite named at the import site in each
                    # host config -- and the case where continuing would leave
                    # the machine with no /root subvolume at all.
                    echo "restoring blank /root subvolume..."
                    if ! btrfs subvolume snapshot /mnt/root-blank /mnt/root; then
                        echo "impermanence: could not restore /root from root-blank"
                        echo "impermanence: does the root-blank subvolume still exist?"
                        fail
                    fi

                    # Once we're done rolling back to a blank snapshot,
                    # we can unmount /mnt and continue on the boot process.
                    umount /mnt
                '';
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
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
# Neither host puts `resume` on the kernel command line today -- durandal has a
# swap device but no boot.resumeDevice, tenacity has no swap -- so nothing is
# wrong now. `unitConfig.ConditionKernelCommandLine = [ "!resume" ]` is the usual
# guard and fails in the safe direction (stops wiping rather than wiping a
# resuming system), but it was left out as a change nobody asked for on a module
# that deletes /root. Add it before configuring hibernation on either machine.
