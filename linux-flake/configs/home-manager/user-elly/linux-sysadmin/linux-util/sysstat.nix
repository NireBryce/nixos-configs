# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ den.bundles.hm.linux-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    sysstat
];
in
{
    home.packages = packageList;
}
;}
