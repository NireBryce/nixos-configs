{ perSystem = {pkgs, lib, ...}:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
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
