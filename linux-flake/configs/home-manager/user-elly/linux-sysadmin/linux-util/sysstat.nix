# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ flake.modules.homeManager.commonLinux.linuxUtil.sysstat =
{ pkgs, ... }:
let packageList = with pkgs; [
    sysstat
];
in
{
    home.packages = packageList;
}
;}
