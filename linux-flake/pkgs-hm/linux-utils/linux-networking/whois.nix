# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        whois
    ];
}
