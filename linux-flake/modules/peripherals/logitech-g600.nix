{ config, ... }:
{
    flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.logitech-g600 ];

    flake.modules.nixos.logitech-g600 = 
{ ... }: 
{
    services.ratbagd.enable = true;         # for piper logitech mouse ctl
}
;}
