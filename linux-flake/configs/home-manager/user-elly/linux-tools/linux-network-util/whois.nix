# desc = "whois lookup https://packages.qa.debian.org/w/whois.html";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    whois
];
in
{
    home.packages = packageList;
}
;}
