{ pkgs, ... }:
{
# whois lookup https://packages.qa.debian.org/w/whois.html
    home.packages = with pkgs; [
        whois
    ];
}
