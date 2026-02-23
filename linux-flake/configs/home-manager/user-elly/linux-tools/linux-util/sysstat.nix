# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    sysstat
];
in
{
    home.packages = packageList;
}
;}
