{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.yq-go ];

    flake.modules.homeManager.yq-go =
# desc = "yaml jq https://github.com/mikefarah/yq";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        yq-go
    ];
}
;}
