{
    pkgs,
    ...
}:
 
{
    home.packages = with pkgs;[
        fd                            # `find` alternative                        https://github.com/sharkdp/fd
        ripgrep                       # `rg` very fast grep replacement           https://github.com/BurntSushi/ripgrep
        fselect
    ];
}
