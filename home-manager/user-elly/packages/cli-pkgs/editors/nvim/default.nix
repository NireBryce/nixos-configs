{ 
    pkgs,
    ... 
}: 
{
    imports = [
        
    ];
    home.packages = with pkgs;[ 
        neovim                        # text editor                               https://neovim.io/
    ];
}


