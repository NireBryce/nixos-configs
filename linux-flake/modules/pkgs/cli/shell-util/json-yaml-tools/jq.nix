{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.jq ];

    flake.modules.homeManager.jq =
# desc = "jq https://github.com/stedolan/jq";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        jq
    ];
}
;}
