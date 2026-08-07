{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.whois ];

    flake.modules.homeManager.whois =
# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        whois
    ];
}
;}
