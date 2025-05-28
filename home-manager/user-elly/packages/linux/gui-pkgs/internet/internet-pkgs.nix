{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        firefox                       # TODO: also installed as a system package. https://www.mozilla.org/en-US/firefox/

    ];
}
