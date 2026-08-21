# nire-cube's disk layout: LUKS + btrfs, root/home/nix/persist/log +
# root-blank, PLUS the secureboot subvolume (mounted at /var/lib/sbctl),
# no swap. See flake/doc/disko-impermanence-layout.md and
# nire/impermanence/_disko/impermanence-luks-btrfs.nix, which this wires in
# rather than restating.
#
# includeSecureboot = true here, unlike lego's disko-lego.nix, because this
# host is meant to be full parity with durandal (see cube-configuration.nix),
# and durandal's own hardware-configuration.nix has the `secureboot` subvolume
# alongside boot-durandal.nix's sbctl package. swapSize is left at its default
# (null, no swap) -- durandal's swap is a dedicated partition sized for that
# machine's real disk, and there's no real disk here yet to size one against;
# add it once the actual layout is known, same as any other REPLACE-ME value
# in this file.
#
# device IS NOT A REAL PATH. It is deliberately unmistakable-fake, not a
# plausible-looking guess like "/dev/nvme0n1" -- cube has not been installed,
# there is no real disk to point at yet, and a plausible-looking placeholder
# is a real hazard here: /dev/nvme0n1 exists on plenty of machines, including
# this repo's own tenacity and testbed, so if this config were ever run
# through disko's actual partitioning step unmodified, on the wrong machine,
# a plausible path would silently wipe whatever disk is actually there. This
# one fails loudly instead -- "device does not exist" -- which is the point.
#
# CHANGE THIS to the real device (check with `lsblk` or `disko-install
# --dry-run` first) before ever running disko for real, and nowhere else --
# everything else in this file, and in the template it calls, is real.
#
# `inputs.disko.nixosModules.disko` is imported here, not inside the template
# itself: the template only produces `disko.devices`/`fileSystems` VALUES, it
# does not declare the `disko.devices` OPTION those values need to land on.
# Importing the module here, once, alongside the values, is how every disko
# example in disko's own repo structures it.
{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            imports = [
                inputs.disko.nixosModules.disko
                (import ../../../nire/impermanence/_disko/impermanence-luks-btrfs.nix {
                    device = "/dev/disk/by-id/REPLACE-ME-before-running-disko";
                    includeSecureboot = true;
                    # luksName, espSize, swapSize all left at their defaults --
                    # "enc", 512M, no swap.
                })
            ];
        };
}
