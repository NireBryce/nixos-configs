{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        btop                          # `htop` alternative                        https://github.com/aristocratos/btop
        hyfetch                       # neofetch replacement                      https://github.com/hykilpikonna/HyFetch
    ];
}


