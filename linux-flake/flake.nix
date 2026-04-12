{
    outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
        imports = [ (inputs.import-tree ./modules) ];

        # Sets _module.args.nireLib to all utility functions defined under modules/_lib/.
        # Any .nix file placed there is automatically picked up and its exported
        # functions merged into nireLib.
        #
        # Usage in any module:
        #   { lib, nireLib, ... }: let
        #     namespaceName = nireLib.findNamespaceUp (dirOf __curPos.file);
        #   in { ... }
        _module.args.nireLib =
        let
            lib    = inputs.nixpkgs.lib;
            libDir = ./modules/_lib;
        in
        lib.pipe (builtins.readDir libDir) [
            (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name))
            (lib.mapAttrs (name: _: import (libDir + "/${name}") {}))
            (lib.attrValues)
            (lib.foldl' lib.mergeAttrs {})
        ];
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
