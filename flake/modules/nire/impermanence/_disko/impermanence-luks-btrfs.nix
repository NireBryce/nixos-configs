# A reusable disko config reproducing the LUKS + btrfs subvolume layout
# durandal and tenacity already use by hand. Not wired into any host --
# nothing imports this file today. See flake/doc/disko-impermanence-layout.md
# for what this is, why it exists unused, and how to actually use it.
#
# Not a flake-parts module. Curried: call it with this host's own parameters
# to get back a NORMAL nixosModule (a function of `{ lib, ... }`), which is
# what a host's own imports list actually wants. Safe to sit under modules/
# because import-tree ignores any path containing "/_" by default -- same
# rule _templates/dirsAsCategory.nix and _lib/mkPkgModule.nix already rely on.
#
# Subvolumes match hardware-configuration.nix / hardware-tenacity.nix exactly:
# root, home, nix, persist, log, and an unmounted root-blank that
# WARN-impermanence.nix snapshots from on every boot
# (`btrfs subvolume snapshot /mnt/root-blank /mnt/root`, read from that file
# directly before writing this). secureboot is durandal's own addition, not
# universal, hence includeSecureboot rather than always including it.
#
# No LUKS keyFile/passwordFile set anywhere in here on purpose: disko's own
# luks type defaults `askPassword` to true whenever none of
# keyFile/passwordFile/enrollFido2 are set (lib/types/luks.nix), which means
# both disko itself (at partitioning time) and boot.initrd.luks.devices (at
# every subsequent boot) prompt interactively -- the same thing durandal and
# tenacity actually do today. Automating that is a real, separate decision
# (key file on a USB stick, TPM enrollment, etc.) and does not belong in a
# generic template.
{ device
, luksName ? "enc"        # matches durandal/tenacity's own mapper name; WARN-
                            # impermanence.nix derives its ordering from
                            # whatever boot.initrd.luks.devices actually
                            # contains, so nothing downstream requires "enc"
                            # specifically, but keeping it makes a fresh host
                            # look like the other two rather than needing its
                            # own explanation.
, espSize ? "512M"
, includeSecureboot ? false # durandal-specific (sbctl, /var/lib/sbctl).
, swapSize ? null           # null = no swap partition, matching tenacity.
                            # Set e.g. "8G" for a durandal-style swap file
                            # subvolume instead.
}:
{ lib, ... }:
    let
        secureVol = lib.optionalAttrs includeSecureboot {
            "/secureboot" = {
                mountpoint = "/var/lib/sbctl";
                mountOptions = [ "compress=zstd" "noatime" ];
            };
        };
        swapVol = lib.optionalAttrs (swapSize != null) {
            "/swap" = {
                mountpoint = "/.swapvol";
                swap.swapfile.size = swapSize;
            };
        };
    in {
        disko.devices.disk.main = {
            type = "disk";
            inherit device;
            content = {
                type = "gpt";
                partitions = {
                    ESP = {
                        size = espSize;
                        type = "EF00";
                        content = {
                            type = "filesystem";
                            format = "vfat";
                            mountpoint = "/boot";
                            mountOptions = [ "umask=0077" ];
                        };
                    };
                    luks = {
                        size = "100%";
                        content = {
                            type = "luks";
                            name = luksName;
                            settings.allowDiscards = true;
                            content = {
                                type = "btrfs";
                                extraArgs = [ "-f" ];
                                subvolumes = {
                                    "/root" = {
                                        mountpoint = "/";
                                        mountOptions = [ "compress=zstd" "noatime" ];
                                    };
                                    "/home" = {
                                        mountpoint = "/home";
                                        mountOptions = [ "compress=zstd" "noatime" ];
                                    };
                                    "/nix" = {
                                        mountpoint = "/nix";
                                        mountOptions = [ "compress=zstd" "noatime" ];
                                    };
                                    "/persist" = {
                                        mountpoint = "/persist";
                                        mountOptions = [ "compress=zstd" "noatime" ];
                                    };
                                    "/log" = {
                                        mountpoint = "/var/log";
                                        mountOptions = [ "compress=zstd" "noatime" ];
                                    };
                                    # No mountpoint: created, never mounted. The
                                    # snapshot source WARN-impermanence.nix's
                                    # initrd rollback unit reads from on every
                                    # boot, not a filesystem entry.
                                    "/root-blank" = { };
                                } // secureVol // swapVol;
                            };
                        };
                    };
                };
            };
        };

        # disko does not set neededForBoot -- both real hosts add it by hand
        # alongside their own generated fileSystems, so this does the same.
        # /root-blank has no mountpoint, so it never gets a fileSystems entry
        # to add this to in the first place.
        #
        # `//` merges attrsets shallowly: it replaces a key present on both
        # sides rather than combining them, so this has to apply `//` to the
        # value AT fileSystems, not to the two top-level module attrsets --
        # `{ fileSystems = {...}; } // lib.optionalAttrs cond { fileSystems = {...}; }`
        # would let the second fileSystems attrset silently replace the first
        # whenever cond is true, dropping persist/log entirely. Caught by
        # actually evaluating this with includeSecureboot = true, not assumed:
        # sbctl's neededForBoot came back true and persist/log's both came back
        # false.
        fileSystems = {
            "/persist".neededForBoot = true;
            "/var/log".neededForBoot = true;
        } // lib.optionalAttrs includeSecureboot {
            "/var/lib/sbctl".neededForBoot = true;
        };
    }
