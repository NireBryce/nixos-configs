{ config, ... }:
{
    flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.boot-workstation ];

    flake.modules.nixos.boot-workstation =
{ lib, pkgs, ...}:
{
        

    environment.systemPackages = with pkgs; [
        sbctl # secure boot ctl  
    ];
    boot.loader = {
        # limine.enable               = lib.mkDefault true;
        # limine.secureBoot.enable    = lib.mkDefault true;
        systemd-boot.enable       = lib.mkDefault true;
        efi.canTouchEfiVariables    = lib.mkDefault true;
    };
}
;}


