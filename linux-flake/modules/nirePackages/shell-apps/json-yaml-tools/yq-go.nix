{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "yaml jq https://github.com/mikefarah/yq";
      home.packages = with pkgs; [
        yq-go
      ];
    };};
}
