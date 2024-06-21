{
  description = "Poetry python application";

  inputs = {
    utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
    poetry2nix,
    ...
  }:
    utils.lib.eachDefaultSystem (system: let
      pkgs          = import nixpkgs {inherit system;};
      python        = pkgs.python3;
      projectDir    = ./.;
    # Create a custom "mkPoetryApplication" API function that under the hood
    #   uses the packages and versions (python3, poetry, etc) from our pinned nixpkgs above
      # inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs;}) mkPoetryApplication;     https://github.com/nix-community/poetry2nix


      overrides = pkgs.poetry2nix.overrides.withDefaults (final: prev: {
        # Python dependency overrides go here
      });
    in {
      packages.default = pkgs.poetry2nix.mkPoetryApplication {
        inherit python projectDir overrides;
        # Non-Python runtime dependencies go here
        propogatedBuildInputs = [];
      };

      devShell = pkgs.mkShell {
        buildInputs = [
          (pkgs.poetry2nix.mkPoetryEnv {
            inherit python projectDir overrides;
          })
          pkgs.poetry
        ];
      };
    });
}
