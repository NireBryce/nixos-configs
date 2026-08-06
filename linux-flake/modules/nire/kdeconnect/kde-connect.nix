{ config, ... }:
{
    flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.kdeconnect ];

    flake.modules.nixos.kdeconnect = 
{ ... }: 
{
    # todo: shouldn't this be a service?
    programs.kdeconnect = {
        enable  = true;      # kde connect
    };
}
;}
