{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        topgrade                      # upgrade all the things (nix sorta broken) https://github.com/topgrade-rs/topgrade
    ];
    home.file = {
        "./.config/topgrade/config.toml"     .source = ./config.toml;
    };
}

