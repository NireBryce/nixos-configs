# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "elly's NixOS configuration";

  outputs = inputs: import ./modules inputs;

  nixConfig = {
    extra-experimental-features = [ "pipe-operators" ];
  };

  inputs = {
    darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:LnL7/nix-darwin";
    };
    den.url = "github:vic/den";
    flake-aspects.url = "github:vic/flake-aspects";
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/master";
    };
    impermanence.url = "github:Nix-community/impermanence";
    import-tree.url = "github:vic/import-tree";
    jovian = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Jovian-Experiments/Jovian-NixOS";
    };
    musnix.url = "github:musnix/musnix";
    nix-index-database = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nix-index-database";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-lib.follows = "nixpkgs";
    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:mic92/sops-nix";
    };
    systems.url = "github:nix-systems/default";
  };

}
