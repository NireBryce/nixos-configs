{ pkgs, ... }:
{
# system stats http://sebastien.godard.pagesperso-orange.fr/
    home.packages = with pkgs; [
        sysstat
    ];
}
