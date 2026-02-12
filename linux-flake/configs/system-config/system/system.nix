{
    ...
}:
{ den.aspects.nixos.provides.system = 
{ lib, ... }: 
{
    programs.nix-ld.enable      = lib.mkDefault true;      # Needed for VSCode remote connection, etc
    services.fwupd.enable       = lib.mkDefault true;      # fwupd
}
;}
