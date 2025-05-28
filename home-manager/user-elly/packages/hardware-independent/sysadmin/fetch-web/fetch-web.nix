
{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        curl                          # `curl`                                    https://curl.se/download.html
        wget                          # its like curl but different               https://www.gnu.org/software/wget/
    ];
}

