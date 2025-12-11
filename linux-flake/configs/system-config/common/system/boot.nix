{
    lib,
    pkgs,
    ...
}:
let
    packageList = with pkgs; [
        sbctl           # secure boot ctl  
    ];
in
{
    environment.systemPackages = packageList;

    boot.loader = {
        limine.enable             = lib.mkDefault true;
        # systemd-boot.enable       = lib.mkDefault true;
        efi.canTouchEfiVariables  = lib.mkDefault true;
    };
}
