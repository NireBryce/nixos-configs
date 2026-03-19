# desc = "network scanner http://www.nmap.org/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nmap
    ];
}
