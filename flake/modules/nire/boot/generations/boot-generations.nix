# How many generations the bootloader keeps.
#
# In a subdirectory, not directly in nire/boot/, because a category collects
# from its *sub*directories only -- a .nix file sitting straight in the category
# directory is collected by nothing. And named boot-generations rather than
# boot.nix: a module's name is its filename, so boot.nix would declare
# flake.modules.nixos.boot, which is this category's own name, and the two would
# silently MERGE rather than conflict. That exact collision is why
# boot-durandal.nix carries the name it does; `just modules` fails on it now.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # systemd-boot's default is `null`, which means keep every
            # generation forever.
            #
            # Measured on durandal 2026-08-14, straight after the 26.05 -> 26.11
            # switch: a 1021M ESP, 580M used, 442M free, 6 entries -- and that
            # one generation cost ~76M. So the unlimited default was about five
            # generations from filling the partition.
            #
            # Worth a cap rather than a reminder to prune, because a full ESP
            # fails the *switch*, part-way through installing the kernel. That is
            # a worse place to find out than a full /nix.
            #
            # 10 is chosen against that 442M of headroom: ~76M each keeps the
            # steady state inside the partition with room for a kernel bump,
            # which is when generations are largest.
            #
            # tenacity's ESP has NOT been measured. 10 is still safe there --
            # it can only ever keep fewer generations than the `null` default
            # did -- but if that partition turns out to be tight, this is the
            # number to revisit, and it should become per-host rather than
            # shared at that point.
            #
            # This only bounds what systemd-boot keeps in /boot. It does not
            # collect the system profile: `nh clean` and nix-collect-garbage
            # still own that, and a generation can be gone from the boot menu
            # while its closure is still in the store.
            boot.loader.systemd-boot.configurationLimit = 10;
        };
}
