inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [
    # den
    inputs.den.flakeModule

    
    # inputs.flake-aspects.flakeModule

    # flake-file: provides the `write-flake` app that regenerates flake.nix.
    inputs.flake-file.flakeModules.default

    # Auto-discovers and imports every .nix file under configs/.
    # This is what makes the aspect pattern zero-boilerplate: no central list.
    (inputs.import-tree ./modules)

  ];
}
