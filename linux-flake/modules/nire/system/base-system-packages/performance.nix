{ den, lib, ... }:
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
        auto-cpufreq # https://github.com/AdnanHodzic/auto-cpufreq
      ];
    };
  };
}
