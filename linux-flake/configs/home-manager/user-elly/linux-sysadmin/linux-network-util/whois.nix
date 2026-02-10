# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    whois
];
in
{
    home.packages = packageList;
}
;}
