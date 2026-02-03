# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ flake.modules.homeManager.commonLinux.networkUtil.whois =
{ pkgs, ... }:
let packageList = with pkgs; [
    whois
];
in
{
    home.packages = packageList;
}
;}
