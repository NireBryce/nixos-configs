{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
    ${aspectChain} = den.lib.perUser {
        homeManager = 
            { lib, ... }: 
            {
                home.stateVersion   = lib.mkDefault "22.11";
                home.username       = lib.mkDefault "elly";
                home.homeDirectory  = lib.mkDefault "/home/elly"; # Darwin is different
            };
    };

}
