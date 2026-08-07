{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.curl ];

    flake.modules.homeManager.curl =
# desc = "curl https://curl.se/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        curl
    ];
}
;}
