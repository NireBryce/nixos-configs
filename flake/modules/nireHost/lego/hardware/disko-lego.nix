# nire-lego's disk layout: LUKS + btrfs, root/home/nix/persist/log +
# root-blank, no secureboot, no swap. Structurally identical to
# nire-tenacity's -- see flake/doc/disko-impermanence-layout.md and
# nire/impermanence/_disko/impermanence-luks-btrfs.nix, which this wires in
# rather than restating.
#
# device IS NOT A REAL PATH. It is deliberately unmistakable-fake, not a
# plausible-looking guess like "/dev/nvme0n1" -- lego has not been installed,
# there is no real disk to point at yet, and a plausible-looking placeholder
# is a real hazard here: /dev/nvme0n1 exists on plenty of machines, including
# this repo's own tenacity, so if this config were ever run
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
                    # luksName, espSize, includeSecureboot, swapSize all left
                    # at their defaults -- "enc", 512M, no secureboot, no
                    # swap -- which is what makes this identical to tenacity's
                    # own layout rather than merely similar to it.
                })
            ];
        };
}
