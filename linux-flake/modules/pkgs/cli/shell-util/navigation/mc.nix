{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.mc ];

    flake.modules.homeManager.mc =
# desc = "midnight commander file browser";
{ pkgs, ... }:


{
    home.packages = with pkgs; [
        mc
    ];
}
;}
