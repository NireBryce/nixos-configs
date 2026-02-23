# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    whois
];
in
{
    home.packages = packageList;
}
;}
