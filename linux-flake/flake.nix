{
    description = "";
    
    nixConfig = {
        extra-experimental-features = [ "pipe-operators" ];
    };

    outputs = 
        inputs: inputs.flake-parts.lib.mkFlake 
        { inherit inputs; } 
        (inputs.import-tree ./modules);

#####################

    inputs = {
        nixpkgs.url                                = "github:NixOS/nixpkgs/nixos-unstable";
        nixpkgs-lib.follows                        = "nixpkgs";
        
        flake-parts.url                            = "github:hercules-ci/flake-parts";
        flake-parts.inputs.nixpkgs-lib.follows     = "nixpkgs-lib";
        
        systems.url                                = "github:nix-systems/default";
        import-tree.url                            = "github:vic/import-tree";
        # ── Dendritic toolchain ───────────────────────────────────────────────────
        den.url                                    = "github:vic/den";
        flake-aspects.url                          = "github:vic/flake-aspects";
        # flake-file.url                             = "github:vic/flake-file";

        # ── Home Manager ──────────────────────────────────────────────────────────
        home-manager.url                           = "github:nix-community/home-manager/master";
        home-manager.inputs.nixpkgs.follows        = "nixpkgs";

        # ── Darwin ────────────────────────────────────────────────────────────────
        darwin.url                                 = "github:LnL7/nix-darwin";
        darwin.inputs.nixpkgs.follows              = "nixpkgs";

        # ── Handheld / SteamOS ────────────────────────────────────────────────────
        jovian.url                                 = "github:Jovian-Experiments/Jovian-NixOS";
        jovian.inputs.nixpkgs.follows              = "nixpkgs";

        
        # ── Impermanence ──────────────────────────────────────────────────────────
        impermanence.url                           = "github:Nix-community/impermanence";

        # ── Secrets ───────────────────────────────────────────────────────────────
        sops-nix.url                               = "github:mic92/sops-nix";
        sops-nix.inputs.nixpkgs.follows            = "nixpkgs";

        # ── Nix utilities ─────────────────────────────────────────────────────────
        nixos-hardware.url                         = "github:NixOS/nixos-hardware/master";
        nix-index-database.url                     = "github:nix-community/nix-index-database";
        nix-index-database.inputs.nixpkgs.follows  = "nixpkgs";
        
        # vic
        with-inputs.url = "github:vic/with-inputs";
        with-inputs.flake = false;
    };
    
}
