
# https://github.com/vic/vix/blob/den/modules/dendritic.nix
# { inputs, lib, ... }:
# {
#   flake-file.inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
#   flake-file.inputs.flake-file.url = lib.mkDefault "github:vic/flake-file";
#   flake-file.inputs.den.url = lib.mkDefault "github:vic/den";
#   imports = [
#     (inputs.flake-file.flakeModules.dendritic or { })
#     (inputs.den.flakeModules.dendritic or { })
#   ];
# }

{ inputs, lib, ... }:
{
    flake-file.inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-file.inputs.flake-file.url = lib.mkDefault "github:vic/flake-file";
    flake-file.inputs.den.url = lib.mkDefault "github:vic/den";
    imports = [
        (inputs.flake-file.flakeModules.dendritic or { })
        (inputs.den.flakeModules.dendritic or { })
    ];
}
