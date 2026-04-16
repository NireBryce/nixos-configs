{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perHost {
    nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        cargo
        rustc
        rustup
        rustfmt
        clippy
        rust-analyzer
      ];
    };
  };
}
