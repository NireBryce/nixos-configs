# A reusable disko config reproducing the LUKS + btrfs subvolume layout
# durandal and tenacity already use by hand. Not wired into any host --
# nothing imports this file; see flake/doc/disko-impermanence-layout.md for
# what this is, why it exists unused, and how to use it.
#
# Not a flake-parts module. Curried: call it with this host's parameters to
# get back a NORMAL nixosModule (a function of `{ lib, ... }`), which is
# what a host's imports list wants. Safe under modules/ because import-tree
# ignores any path containing "/_" -- the same rule
# _templates/dirsAsCategory.nix and _lib/mkPkgModule.nix already rely on.
#
# issue #103 asked for a dirsAsCategory.nix here too, mirroring
# root-rollback/ (see that directory's own copy) so a host could opt into
# this disko layout the same way it opts into a homelab child category.
# Deliberately not done: a dirsAsCategory.nix under `_disko/` would itself
# sit on a path containing "/_", so import-tree would skip importing IT too
# -- `flake.modules.nixos._disko` would never exist, making the file dead
# weight rather than a working category. This file already gets the
# independence the issue asked for, just by a different route: nothing
# imports it automatically at all, by design (above), so there was never
# a bundling problem to fix on this side -- only root-rollback needed its
# own dirsAsCategory.nix, to stop being reachable *only* by importing the
# whole `impermanence` umbrella.
#
# Subvolumes match hardware-configuration.nix / hardware-tenacity.nix exactly:
# root, home, nix, persist, log, and an unmounted root-blank that
# WARN-impermanence.nix snapshots from on every boot
# (`btrfs subvolume snapshot /mnt/root-blank /mnt/root`). secureboot is
# durandal's own addition, not universal, hence includeSecureboot rather than
# always including it.
#
# No LUKS keyFile/passwordFile, on purpose: disko's luks type defaults
# `askPassword` to true whenever none of keyFile/passwordFile/enrollFido2 are
# set (lib/types/luks.nix), so disko (at partitioning time) and
# boot.initrd.luks.devices (every subsequent boot) prompt interactively --
# the same thing durandal and tenacity do today. Automating that (USB key
# file, TPM enrollment, etc.) is a real, separate decision and does not
# belong in a generic template.
{ device
, luksName ? "enc"        # matches durandal/tenacity's own mapper name; WARN-
                            # impermanence.nix derives its ordering from
                            # whatever boot.initrd.luks.devices actually
                            # contains, so nothing downstream requires "enc"
                            # specifically; keeping it makes a fresh host
                            # look like the other two.
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
        # alongside their own generated fileSystems; /root-blank has no
        # mountpoint, so it never gets a fileSystems entry to add this to.
        #
        # `//` merges attrsets shallowly (replaces a key present on both
        # sides, does not combine), so `//` must apply to the value AT
        # fileSystems, not the two top-level module attrsets:
        # `{ fileSystems = {...}; } // lib.optionalAttrs cond { fileSystems = {...}; }`
        # would let the second fileSystems silently replace the first
        # whenever cond is true, dropping persist/log entirely (checked with
        # includeSecureboot = true: sbctl's neededForBoot came back true,
        # persist/log's false).
        fileSystems = {
            "/persist".neededForBoot = true;
            "/var/log".neededForBoot = true;
        } // lib.optionalAttrs includeSecureboot {
            "/var/lib/sbctl".neededForBoot = true;
        };
    }
