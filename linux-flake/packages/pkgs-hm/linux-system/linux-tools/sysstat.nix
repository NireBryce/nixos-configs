# desc = "system stats http://sebastien.godard.pagesperso-orange.fr/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        sysstat
    ];
}
