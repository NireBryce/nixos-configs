{
    outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [ (inputs.import-tree ./modules) ];
        
        # Extends the lib module argument with all utility functions defined
        # under modules/_lib/. Any .nix file placed there is automatically
        # picked up and its exported functions merged into lib.
        # Extends the lib module argument with all utility functions defined
        # under modules/_lib/. The _lib/ prefix keeps import-tree from picking
        # them up as modules.
        # _module.args.lib = inputs.nixpkgs.lib.extend (_: _:
        #     inputs.nixpkgs.lib.pipe (builtins.readDir ./modules/_lib) [
        #         (inputs.nixpkgs.lib.filterAttrs (name: type: type == "regular" && inputs.nixpkgs.lib.hasSuffix ".nix" name))
        #         (inputs.nixpkgs.lib.mapAttrs (name: _: import ./modules/_lib/${name} { lib = inputs.nixpkgs.lib; }))
        #         (inputs.nixpkgs.lib.foldl' inputs.nixpkgs.lib.mergeAttrs {})
        #     ]
        # );

        # debug trace
        _module.args.lib = inputs.nixpkgs.lib.mkForce inputs.nixpkgs.lib.extend (_: _:
    let
        result = inputs.nixpkgs.lib.pipe (builtins.readDir ./modules/_lib) [
            (inputs.nixpkgs.lib.filterAttrs (name: type: type == "regular" && inputs.nixpkgs.lib.hasSuffix ".nix" name))
            (inputs.nixpkgs.lib.mapAttrs (name: _: import ./modules/_lib/${name} { lib = inputs.nixpkgs.lib; }))
            (inputs.nixpkgs.lib.foldl' inputs.nixpkgs.lib.mergeAttrs {})
        ];
    in builtins.trace "lib extensions: ${builtins.toJSON (builtins.attrNames result)}" result
);
    };
    

    nixConfig = {
        extra-experimental-features = [ "pipe-operators" ];
    };

    inputs = {
        nixpkgs.url                                = "github:NixOS/nixpkgs/nixos-unstable";
        nixpkgs-lib.follows                        = "nixpkgs";
        
        flake-parts.url                            = "github:hercules-ci/flake-parts";
        flake-parts.inputs.nixpkgs-lib.follows     = "nixpkgs-lib";
        
        # ── Dendritic toolchain ───────────────────────────────────────────────────
        # systems.url                                = "github:nix-systems/default";
        import-tree.url                            = "github:vic/import-tree";
        den.url                                    = "github:vic/den";
        flake-aspects.url                          = "github:vic/flake-aspects";

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
    };


}
