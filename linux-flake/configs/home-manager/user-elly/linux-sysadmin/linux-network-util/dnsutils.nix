# desc = "provides `dig` + `nslookup`";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dnsutils
    ];
}
;}
