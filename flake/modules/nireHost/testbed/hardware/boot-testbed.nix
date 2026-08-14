# Named boot-testbed.nix, not boot.nix, for the same reason boot-durandal.nix
# is not called boot.nix: a module's filename is its attribute name, and
# `nire/boot/` is a category of that same name. See boot-durandal.nix's own
# history note for what merging the two silently did there.
#
# X270 is UEFI-capable, so systemd-boot rather than grub, same as durandal.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            boot.loader = {
                systemd-boot.enable = lib.mkDefault true;
                efi.canTouchEfiVariables = lib.mkDefault true;
            };
        };
}
