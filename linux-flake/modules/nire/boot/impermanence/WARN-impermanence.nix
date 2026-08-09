{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = {
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
            # reset / at each boot
            boot.initrd = {
                enable = true;
                supportedFilesystems = [ "btrfs" ];
                systemd.services.restore-root = {
                    description = "Rollback btrfs rootfs";
                    wantedBy = [ "initrd.target" ];
                    requires = [
                        "dev-mapper-enc.device" # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
                    ];
                    after = [
                        "dev-mapper-enc.device" # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
                        "systemd-cryptsetup@nire-durandal.service"
                    ];#TODO: fix me to be general this is just to make it work for now
                    before = [ "sysroot.mount" ];
                    unitConfig.DefaultDependencies = "no";
                    serviceConfig.Type = "oneshot";
                    script = ''
                        mkdir -p /mnt

                        # We first mount the btrfs root to /mnt
                        # so we can manipulate btrfs subvolumes.
                        mount -o subvol=/ /dev/mapper/enc /mnt

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

                        echo "restoring blank /root subvolume..."
                        btrfs subvolume snapshot /mnt/root-blank /mnt/root

                        # Once we're done rolling back to a blank snapshot,
                        # we can unmount /mnt and continue on the boot process.
                        umount /mnt
                    '';
                };
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
# STILL OUTSTANDING — this module is durandal-only, and not by choice
#
# `systemd.services.restore-root` waits on
# `systemd-cryptsetup@nire-durandal.service`, which is hardcoded to one host and
# carries its own "fix me to be general" note. Both machines happen to name the
# LUKS device `enc`, so `dev-mapper-enc.device` is fine; only the cryptsetup unit
# name is host-specific.
#
# That is why nire-tenacity does not import the `boot` category, despite its disk
# having the persist and log subvolumes that only make sense with impermanence.
# See TENACITY-PLAN.md.
