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
