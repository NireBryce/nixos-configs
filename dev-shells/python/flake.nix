{
  inputs.nixpkgs.url                                 = "github:NixOS/nixpkgs/nixos-unstable";


  outputs = { self, nixpkgs, lib }:

  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    python = pkgs.python313;
    # https://github.com/NixOS/nixpkgs/blob/c339c066b893e5683830ba870b1ccd3bbea88ece/nixos/modules/programs/nix-ld.nix#L44
    # > We currently take all libraries from systemd and nix as the default.
    pythonLdLibPath = lib.makeLibraryPath (with pkgs; [
      zlib
      zstd
      stdenv.cc.cc
      curl
      openssl
      attr
      libssh
      bzip2
      libxml2
      acl
      libsodium
      util-linux
      xz
      systemd
    ]);
    patchedpython = (python.overrideAttrs (
      previousAttrs: {
        # Add the nix-ld libraries to the LD_LIBRARY_PATH.
        # creating a new library path from all desired libraries
        postInstall = previousAttrs.postInstall + ''
          mv  "$out/bin/python3.13" "$out/bin/unpatched_python3.13"
          cat << EOF >> "$out/bin/python3.13"
          #!/run/current-system/sw/bin/bash
          export LD_LIBRARY_PATH="${pythonldlibpath}"
          exec "$out/bin/unpatched_python3.13" "\$@"
          EOF
          chmod +x "$out/bin/python3.13"
        '';
      }
    ));
    # if you want poetry
    patchedpoetry =  ((pkgs.poetry.override { python3 = patchedpython; }).overrideAttrs (
      previousAttrs: {
        # same as above, but for poetry
        # not that if you dont keep the blank line bellow, it crashes :(
        postInstall = previousAttrs.postInstall + ''

          mv "$out/bin/poetry" "$out/bin/unpatched_poetry"
          cat << EOF >> "$out/bin/poetry"
          #!/run/current-system/sw/bin/bash
          export LD_LIBRARY_PATH="${pythonLdLibPath}"
          exec "$out/bin/unpatched_poetry" "\$@"
          EOF
          chmod +x "$out/bin/poetry"
        '';
      }
    ));
  in
  {

    
    environment.systemPackages = with pkgs; [
      ruff
      python3Packages.venvShellHook
      python3Packages.rich
      python3Packages.ruff
      python3Packages.more-itertools
      python3Packages.isort
      python3Packages.setuptools
      python3Packages.toml
      python3Packages.pip
      patchedpython

      # if you want poetry
      patchedpoetry
    ];
    shellHook = ''
      # Allow the use of wheels.
      SOURCE_DATE_EPOCH=$(date +%s)
      # Augment the dynamic linker path
      export "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pythonLdLibPath}"
      # Setup the virtual environment if it doesn't already exist.
      VENV=.venv
      if test ! -d $VENV; then
        virtualenv $VENV
      fi
      source ./$VENV/bin/activate
      export PYTHONPATH=$PYTHONPATH:`pwd`/$VENV/${myPython.sitePackages}/
  '';
  };
}
