{ self, inputs, ...}:
{ flake.modules.nixos.system = 
{ pkgs, lib, ... }: 
{
    programs.nix-ld.enable      = lib.mkDefault true;      # Needed for VSCode remote connection, etc
    services.fwupd.enable       = lib.mkDefault true;      # fwupd
    console = {
        keyMap  = "us";
        font    = "Lat2-Terminus16";
    };
    i18n.defaultLocale  = lib.mkDefault "en_US.UTF-8";
    time.timeZone       = lib.mkDefault "America/New_York"; 
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
