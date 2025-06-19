{
    pkgs,
    ...
}:
 
{
    imports = [
        
    ];
    home.packages = with pkgs;[
        bat                           # `cat`, `less` alternative (w/ SynHi)      https://github.com/sharkdp/bat
        moar  # better pager for some things              https://github.com/walles/moar
        glow    # terminal markdown viewer https://github.com/charmbracelet/glow
    ];
}
