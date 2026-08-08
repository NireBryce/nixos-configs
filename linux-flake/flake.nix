{
    description = "NixOS and Home Manager configuration for nire-durandal";

    outputs = inputs: inputs.flake-parts.lib.mkFlake {
        inherit inputs;
    }
    {
        imports = [
            # declares flake.modules.<class>.<name>, which every module here writes into
            inputs.flake-parts.flakeModules.modules
            (inputs.import-tree ./modules)
        ];
        systems = [
            "x86_64-linux"
            "aarch64-darwin"
        ];
    };

    inputs = {
        nixpkgs.url                                = "github:NixOS/nixpkgs/nixos-unstable";
        nixpkgs-lib.follows                        = "nixpkgs";
        
        flake-parts.url                            = "github:hercules-ci/flake-parts";
        flake-parts.inputs.nixpkgs-lib.follows     = "nixpkgs-lib";

        # ── Dendritic toolchain ───────────────────────────────────────────────────
        # systems.url                                = "github:nix-systems/default";
        import-tree.url                            = "github:vic/import-tree";
        # den.url                                    = "github:vic/den";
        # flake-aspects.url                          = "github:vic/flake-aspects";

        # ── Home Manager ──────────────────────────────────────────────────────────
        home-manager.url                           = "github:nix-community/home-manager/master";
        home-manager.inputs.nixpkgs.follows        = "nixpkgs";

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
    };


}
