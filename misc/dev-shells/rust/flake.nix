{
  description = "Rust Rover environment";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        rust-overlay.url = "github:oxalica/rust-overlay";
        rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
        flake-utils = {
            url = "github:numtide/flake-utils";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
        system:
        let
            pkgs = import nixpkgs {
                inherit system;
                overlays = [ (import rust-overlay) ];
            };

            rustToolchain = pkgs.rust-bin.stable.latest.default.override {
                extensions = [ "rust-src" "clippy" "rustfmt" ];
            };
        in 
        {
            devShell = pkgs.mkShell {
                nativeBuildInputs = with pkgs; [
                    rustToolchain
                ];

                buildInputs = with pkgs; [
                    openssl.dev
                    pkg-config
                    rust-analyzer
                    jetbrains.rust-rover
                ];
            
                env = {
                    RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
                    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
                    RUST_BACKTRACE = "1";
                };

                shellHook = ''
                  echo "Rust $(rustc --version)"
                  echo "Cargo $(cargo --version)"
                '';
            };
        }
    );
}
