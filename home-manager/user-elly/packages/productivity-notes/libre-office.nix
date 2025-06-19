{ ... }:
{
    description = "office productivity software https://www.libreoffice.org/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            libreoffice-qt
        ];
    in 
    {
        home.packages = packageList;
    };
}
