# Named boot-cube.nix, not boot.nix, for the same reason boot-durandal.nix
# is not called boot.nix: a module's filename is its attribute name, and
# `nire/boot/` is a category of that same name. See boot-durandal.nix's own
# history note for what merging the two silently did there.
#
# GMKtec Nucbox G11 is UEFI-capable, so systemd-boot rather than grub, same
# as durandal. sbctl carried over too, for the same reason as durandal's --
# this file is meant to be full parity with boot-durandal.nix, just renamed
# so the two don't merge.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
            sbctl # secure boot ctl
            ];
            boot.loader = {
                systemd-boot.enable = lib.mkDefault true;
                efi.canTouchEfiVariables = lib.mkDefault true;
            };
        };
}
