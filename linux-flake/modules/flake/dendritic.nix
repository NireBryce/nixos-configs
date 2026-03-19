{ inputs, den, ... }:
{

  # imports = [
  #   (inputs.flake-file.flakeModules.dendritic or { })
  #   (inputs.den.flakeModules.dendritic or { })
  # ];

  inputs.flake-file.inputs.den.url = "github:vic/den";
  inputs.flake-file.inputs.flake-file.url = "github:vic/flake-file";
  inputs.flake-file.inputs.flake-aspects.url = "github:vic/flake-aspects";
  inputs.flake-file.inputs.import-tree.url = "github:vic/import-tree";
  inputs.flake-file.inputs.with-inputs.url = "github:vic/with-inputs";
  inputs.flake-file.inputs.with-inputs.flake = false;

# https://github.com/vic/vix/blob/unflake/modules/flake/dendritic.nix
}
