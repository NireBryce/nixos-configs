{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.dnsutils ];

    flake.modules.homeManager.dnsutils =
# desc = "provides `dig` + `nslookup`";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dnsutils
    ];
}
;}
