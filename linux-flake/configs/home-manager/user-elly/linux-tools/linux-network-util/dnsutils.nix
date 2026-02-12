# desc = "provides `dig` + `nslookup`";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dnsutils
    ];
}
;}
