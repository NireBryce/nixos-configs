{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        environment.systemPackages = with pkgs; [
            sbctl # secure boot ctl  
        ];
        boot.loader = {
            # limine.enable               = lib.mkDefault true;
            # limine.secureBoot.enable    = lib.mkDefault true;
            systemd-boot.enable       = lib.mkDefault true;
            efi.canTouchEfiVariables    = lib.mkDefault true;
        };
    };
}


