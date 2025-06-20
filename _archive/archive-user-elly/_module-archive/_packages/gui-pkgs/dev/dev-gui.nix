{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
      # git                       # git                                       # git
        github-desktop                # github-desktop                            https://desktop.github.com/
    ];
}
