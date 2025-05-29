{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
        vscode-fhs                    # vscode                                    https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/editors/vscode/
    ];
}
