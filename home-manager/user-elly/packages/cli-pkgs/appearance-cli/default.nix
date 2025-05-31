{
    pkgs,
    ...
}:
 
{
    imports = [
        ./dircolors
        ./starship
    ];
    home.packages = with pkgs;[
        vivid                         # LS_COLORS generator                       https://github.com/sharkdp/vivid
    ];
}
