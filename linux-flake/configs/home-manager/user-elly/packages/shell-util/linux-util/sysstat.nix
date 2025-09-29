# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ pkgs, ... }:
let packageList = with pkgs; [
    sysstat
];
in
{
    home.packages = packageList;
}
