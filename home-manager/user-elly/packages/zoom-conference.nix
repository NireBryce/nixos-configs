{ ... }:
{
    # desc = "zoom videoconferencing software https://zoom.us/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        zoom-us
    ];
    in
    {
        home.packages = packageList;
    };
}
