{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        qpwgraph                      # sound mixer                               https://github.com/rncbc/qpwgraph
    ];
}
