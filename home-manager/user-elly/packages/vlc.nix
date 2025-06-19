{ ... }:
{
    # desc = "VLC media player";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            vlc
        ];
    in 
    {
        home.packages = packageList;
    };
}
