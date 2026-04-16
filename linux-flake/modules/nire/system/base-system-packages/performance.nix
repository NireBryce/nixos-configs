{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        auto-cpufreq # https://github.com/AdnanHodzic/auto-cpufreq
      ];
    };
  };
}
