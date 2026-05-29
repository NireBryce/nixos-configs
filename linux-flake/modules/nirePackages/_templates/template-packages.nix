# Not a functional module, exists to remind me I planned to do this

{ import-tree }:
{
    flake.modules.nixos.pkgs-gui  =
    { 
        imports = [ 
            (import-tree ../../packages/pkgs-gui)
        ];
    };

    flake.modules.nixos.pkgs-system = 
    { 
        imports = [ 
            (import-tree ../../packages/pkgs-system)
        ];
    };
}
