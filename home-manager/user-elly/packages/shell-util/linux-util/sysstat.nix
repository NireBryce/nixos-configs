{ ... }:
{
    description = "system stats http://sebastien.godard.pagesperso-orange.fr/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        sysstat
    ];
    in
    {
        home.packages = packageList;
    };
}
