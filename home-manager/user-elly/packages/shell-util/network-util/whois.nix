# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ pkgs, ... }:
let packageList = with pkgs; [
    whois
];
in
{
    home.packages = packageList;
}
