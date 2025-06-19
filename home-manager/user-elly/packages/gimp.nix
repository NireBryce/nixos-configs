{ ... }:
{
    # desc = " GNU Image Manipulation Program. https://www.gimp.org";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            gimp
        ];
    in 
    {
        home.packages = packageList;
    };
}
