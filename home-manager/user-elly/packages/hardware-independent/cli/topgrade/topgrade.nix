{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        topgrade                      # upgrade all the things (nix sorta broken) https://github.com/topgrade-rs/topgrade
    ];
    home.file = {
        "./.config/topgrade/config.toml" = { 
            executable = false; 
            text = ''
                [misc]
                # Disable specific steps - same options as the command line flag
                disable = [
                    "nix", 
                    "uv",
                    "micro",
                    "vim",
                    "vscode",

                    # nixos
                    "system" 
                ]
            ''; 
        };
    };
}

