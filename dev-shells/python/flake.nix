{
  # description = "Python dev environment";

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

            python = pkgs.python3;
        in
        {
            devShell = pkgs.mkShell {
                nativeBuildInputs = with pkgs; [
                    python
                    uv
                ];

                buildInputs = with pkgs; [
                    ruff
                    pyright
                ];

                env = {
                    # keeps uv from reaching for a network-fetched interpreter --
                    # it uses this nixpkgs python instead.
                    UV_PYTHON = "${python}/bin/python3";
                    UV_PYTHON_DOWNLOADS = "never";
                    # venv lives in-project so editors/pyright find it without config.
                    UV_PROJECT_ENVIRONMENT = ".venv";
                    PYTHONDONTWRITEBYTECODE = "1";
                };

                shellHook = ''
                  echo "Python $(python3 --version)"
                  echo "uv $(uv --version)"
                '';
            };
        }
    );
}
