# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    nixos = {
        # The old config force-disabled limine here, with the note "hack,
        # replace after switching tinylaptop to limine". Nothing on this
        # branch enables limine and NixOS defaults it off, so the mkForce is
        # dropped rather than carried over.
        #
        # No efi.canTouchEfiVariables, matching what this host actually ran
        # with. durandal sets it; tenacity never did.
        boot.loader.systemd-boot.enable = lib.mkDefault true;
    };
}
