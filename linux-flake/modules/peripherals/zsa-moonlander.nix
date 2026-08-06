{ config, ... }:
{
    flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.zsa-moonlander ];

    flake.modules.nixos.zsa-moonlander = 
{ ... }: 
{
    hardware.keyboard.zsa.enable        = true;         # zsa keyboard package
}
;}
