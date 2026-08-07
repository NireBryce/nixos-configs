{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.tokei ];

    flake.modules.homeManager.tokei =
# desc = "count lines of code";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        tokei
    ];
}
;}
