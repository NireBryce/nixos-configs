# Declares all flake inputs and top-level flake settings using flake-file options.
# After editing, run `nix run .#write-flake` to regenerate flake.nix from these
# declarations.  The generated flake.nix will carry a "do not edit" header.
{
    flake-file.description = "Nire NixOS configuration";

    flake-file.nixConfig = {
        extra-experimental-features = [ "pipe-operators" ];
    };

    flake-file.inputs = {
        # ── Core framework ────────────────────────────────────────────────────────
        nixpkgs.url                                = "github:NixOS/nixpkgs/nixos-unstable";
        nixpkgs-lib.follows                        = "nixpkgs";

        flake-parts.url                            = "github:hercules-ci/flake-parts";
        flake-parts.inputs.nixpkgs-lib.follows     = "nixpkgs-lib";

        systems.url                                = "github:nix-systems/default";
        import-tree.url                            = "github:vic/import-tree";

        # ── Dendritic toolchain ───────────────────────────────────────────────────
        den.url                                    = "github:vic/den";
        flake-aspects.url                          = "github:vic/flake-aspects";
        flake-file.url                             = "github:vic/flake-file";

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
