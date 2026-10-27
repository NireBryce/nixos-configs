# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# Named boot-cube.nix, not boot.nix, for the same reason boot-durandal.nix is
# not called boot.nix: a module's filename is its attribute name, and
# `general-config/boot/` is a category of that same name. See
# boot-durandal.nix's own history note for what merging the two silently did
# there.
#
# GMKtec Nucbox G11 is UEFI-capable, so systemd-boot rather than grub, same
# as durandal. sbctl carried over too, for the same reason as durandal's --
# this file is meant to be full parity with boot-durandal.nix, just renamed
# so the two don't merge.
{ lib, ... }:
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
        sbctl # secure boot ctl
        ];
        boot.loader = {
            systemd-boot.enable = lib.mkDefault true;
            efi.canTouchEfiVariables = lib.mkDefault true;
        };
    };
}
