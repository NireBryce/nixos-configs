# desc = "provides `dig` + `nslookup`";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dnsutils
    ];
}
;}
