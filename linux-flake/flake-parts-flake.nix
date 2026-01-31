{
    nixConfig = {
        # abort-on-warn = true;
        extra-experimental-features = [ "pipe-operators" ];
        # allow-import-from-derivation = false;
    };
    inputs = {
    # Unstable
        nixpkgs.url
          = "github:NixOS/nixpkgs/nixos-unstable";
        # nixpkgs.url
        #     = "github:NixOS/nixpkgs/nixpkgs-unstable"; # TODO: this is a YOLO fix for https://github.com/nix-community/home-manager/issues/5991,  I have already spent too much time on this
    
    # import-tree
        import-tree.url 
          = "github:vic/import-tree";
    # flake parts
        flake-parts.url = "github:hercules-ci/flake-parts";

    };

    outputs = {
      self,
      import-tree,
      nixpkgs,
      #nixpkgs-stable,                                         # https://nixos-and-flakes.thiscute.world/nixos-with-flakes/downgrade-or-upgrade-packages
      
      flake-parts,
      ... 
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; }
    {
      imports = { };
        systems = [
          "x86_64-linux"
        ];
        perSystem = { ... }: {
          # responsible for system-specific outputs
        }; 
    };
}
