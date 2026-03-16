# desc = "provides `dig` + `nslookup`";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dnsutils
    ];
}
