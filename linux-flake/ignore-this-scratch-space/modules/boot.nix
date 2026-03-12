{ lib, pkgs, ...}:

{
    elly.boot.provides = {
        handheld.nixos = {
            boot.loader = {
                # todo: hack, replace after switching tinylaptop to limine
                limine.enable               = lib.mkForce false;
                limine.secureBoot.enable    = lib.mkForce false;
                systemd-boot.enable         = lib.mkDefault true;
            };
        };

        desktop.nixos = {
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
    };
}


