# GREP NOTE: this file was `boot.nix`, declaring `flake.modules.nixos.boot`.
# That is also the name dirsAsCategory gives the `nire/boot/` category, and
# same-named modules merge silently rather than erroring -- so importing the
# `boot` category also pulled durandal's bootloader in, and importing durandal's
# bootloader also pulled in WARN-impermanence, which deletes /root on boot.
# Durandal wants both, so nothing changed for it; a second host would have been
# surprised. Renamed so the two stay distinct.
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
