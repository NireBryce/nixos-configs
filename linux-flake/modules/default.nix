{
    imports = [ 
        ./flake/flake-inputs.nix 
    ];
    systems = [ "x86-64-linux" ];
    # flake-file.description = "Nire NixOS configuration";

    # flake-file.nixConfig = {
    #     extra-experimental-features = [ "pipe-operators" ];
    # };


    outputs = inputs: 
    inputs.flake-parts.lib.mkFlake { inherit inputs; };
    # (inputs.import-tree ./modules);
    

}

