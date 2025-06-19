{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        gimp                          # GNU Image Manipulation Program.           https://www.gimp.org
    ];
}

