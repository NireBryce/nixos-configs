{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        nix-output-monitor # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
      ];
    };
  };
}
