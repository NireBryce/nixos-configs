{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
    # SteamTinkerLaunch needs these
    # TODO: move to steam config
        xxd
        xdotool
        xorg.xwininfo
        yad
    ];
}
