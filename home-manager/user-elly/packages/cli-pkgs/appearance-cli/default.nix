{
    pkgs,
    ...
}:
 
{
    imports = [
        ./dircolors
        ./starship
        ./vivid         # LS_COLORS generator                       https://github.com/sharkdp/vivid
    ];
}
