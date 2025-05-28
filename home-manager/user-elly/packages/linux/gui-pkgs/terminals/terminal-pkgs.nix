
{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[     
        kitty                         # gpu accelerated terminal                  https://sw.kovidgoyal.net/kitty
        kitty-img                     # kitty image rendering engine, like sixel  https://git.sr.ht/~zethra/kitty-img
        wezterm                       # terminal emulator                         https://github.com/wez/wezterm
    ];
}
