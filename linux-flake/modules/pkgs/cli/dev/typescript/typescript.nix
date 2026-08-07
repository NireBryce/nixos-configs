{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.typescript ];

    flake.modules.homeManager.typescript =
# typescript - it's typescript
{ pkgs, ... }:
{   
    home.packages = with pkgs; [
        typescript
    ];
}
;}
