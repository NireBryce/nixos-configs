{
  # description = "Nix dev environment";

    # Same tool list as flake/modules/dev-shell.nix (this repo's own
    # `nix develop`); that one can't be imported from here because this file
    # gets copied into other projects. Keep the two in step.
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        flake-utils = {
            url = "github:numtide/flake-utils";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
        system:
        let
            pkgs = import nixpkgs {
                inherit system;
            };
        in
        {
            devShell = pkgs.mkShell {
                packages = with pkgs; [
                    # LSPs
                    nixd
                    nil
                    # formatter / linters
                    nixfmt
                    statix
                    deadnix
                    # closure / derivation inspection
                    nix-tree
                    nix-diff
                    nix-du
                    # fetcher calls from repository URLs
                    nurl
                ];
            };
        }
    );
}
