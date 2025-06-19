{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
      obsidian                      # pkm                                       https://obsidian.md/
      libreoffice-qt                # office                                    https://www.libreoffice.org/
    ];
}
