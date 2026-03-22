{ self, inputs, ...}:
{ flake.nixosModules.boot-handheld =
{ lib, ... }: 
{
    boot.loader = {
        # todo: hack, replace after switching tinylaptop to limine
        limine.enable               = lib.mkForce false;
        limine.secureBoot.enable    = lib.mkForce false;
        systemd-boot.enable         = lib.mkDefault true;
    };
}
;}
