{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.entr ];

    flake.modules.homeManager.entr =
# desc = "run commands when file changes";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        entr
    ];
}
;}
