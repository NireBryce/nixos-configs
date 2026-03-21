{inputs, ...}:
{
    flake-file.inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        flake-file.url = "github:vic/flake-file";
        flake-aspects.url = "github:vic/flake-aspects";
        den.url = "github:vic/den";
        import-tree.url = "github:vic/import-tree";
        with-inputs.url = "github:vic/with-inputs";
        with-inputs.flake = false;
    };
    # imports = [ 
    #     (inputs.flake-file.flakeModules.dendritic or { }) 
    #     (inputs.den.flakeModules.dendritic or { })
    # ];

}

# https://github.com/vic/vix/blob/unflake/modules/flake/dendritic.nix
