# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    sysstat
];
in
{
    home.packages = packageList;
}
;}
