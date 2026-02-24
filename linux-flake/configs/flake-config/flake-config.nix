# Declares all flake inputs and top-level flake settings using flake-file options.
# After editing, run `nix run .#write-flake` to regenerate flake.nix from these
# declarations.  The generated flake.nix will carry a "do not edit" header.
{ ... }:
{
    flake-file.description = "elly's NixOS configuration";

    flake-file.nixConfig = {
        extra-experimental-features = [ "pipe-operators" ];
    };

    # ── Core framework ────────────────────────────────────────────────────────
    flake-file.inputs.nixpkgs.url                                = "github:NixOS/nixpkgs/nixos-unstable";
    flake-file.inputs.nixpkgs-lib.follows                        = "nixpkgs";

    flake-file.inputs.flake-parts.url                            = "github:hercules-ci/flake-parts";
    flake-file.inputs.flake-parts.inputs.nixpkgs-lib.follows     = "nixpkgs-lib";

    flake-file.inputs.systems.url                                = "github:nix-systems/default";
    flake-file.inputs.import-tree.url                            = "github:vic/import-tree";

    # ── Dendritic toolchain ───────────────────────────────────────────────────
    flake-file.inputs.den.url                                    = "github:vic/den";
    flake-file.inputs.flake-aspects.url                          = "github:vic/flake-aspects";
    flake-file.inputs.flake-file.url                             = "github:vic/flake-file";

    # ── Home Manager ──────────────────────────────────────────────────────────
    flake-file.inputs.home-manager.url                           = "github:nix-community/home-manager/master";
    flake-file.inputs.home-manager.inputs.nixpkgs.follows        = "nixpkgs";

    # ── Darwin ────────────────────────────────────────────────────────────────
    flake-file.inputs.darwin.url                                 = "github:LnL7/nix-darwin";
    flake-file.inputs.darwin.inputs.nixpkgs.follows              = "nixpkgs";

    # ── Hardware / gaming ─────────────────────────────────────────────────────
    flake-file.inputs.jovian.url                                 = "github:Jovian-Experiments/Jovian-NixOS";
    flake-file.inputs.jovian.inputs.nixpkgs.follows              = "nixpkgs";

    flake-file.inputs.nixos-hardware.url                         = "github:NixOS/nixos-hardware/master";
    flake-file.inputs.musnix.url                                 = "github:musnix/musnix";

    # ── Impermanence ──────────────────────────────────────────────────────────
    flake-file.inputs.impermanence.url                           = "github:Nix-community/impermanence";

    # ── Secrets ───────────────────────────────────────────────────────────────
    flake-file.inputs.sops-nix.url                               = "github:mic92/sops-nix";
    flake-file.inputs.sops-nix.inputs.nixpkgs.follows            = "nixpkgs";

    # ── Nix utilities ─────────────────────────────────────────────────────────
    flake-file.inputs.nix-index-database.url                     = "github:nix-community/nix-index-database";
    flake-file.inputs.nix-index-database.inputs.nixpkgs.follows  = "nixpkgs";
}
