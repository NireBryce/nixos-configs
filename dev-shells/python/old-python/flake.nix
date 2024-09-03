{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    # pythonPackages = pkgs.python3Packages;
    # A list of shell names and their Python versions
    pythonVersions = {
      python310 = pkgs.python310;
      python311 = pkgs.python311;
      python312 = pkgs.python312;
      default   = pkgs.python312;
    };
    # A function to make a shell with a python version
    makePythonShell = shellName: pythonPackage: pkgs.mkShell {
      venvDir = "./.venv";
      

    packages = [ 
        # You could add extra packages you need here too
        pythonPackage
        pkgs.ruff
        pkgs.python3Packages.venvShellHook
        pkgs.python3Packages.rich
        pkgs.python3Packages.pytest
        pkgs.python3Packages.more-itertools
        pkgs.python3Packages.isort
        pkgs.python3Packages.setuptools
        pkgs.python3Packages.toml
        pkgs.python3Packages.pip
      ]; 
      # You can also add commands that run on shell startup with shellHook
      shellHook = ''
        echo "Now entering ${shellName} environment."
      '';
      postVenvCreation = ''
        unset SOURCE_DATE_EPOCH
        pip install -r requirements.txt
      '';

      postShellHook = ''
        unset SOURCE_DATE_EPOCH
      '';
    };
      in
      {
        # mapAttrs runs the given function (makePythonShell) against every value
        # in the attribute set (pythonVersions) and returns a new set
        devShells.x86_64-linux = builtins.mapAttrs makePythonShell pythonVersions;
      };
}

