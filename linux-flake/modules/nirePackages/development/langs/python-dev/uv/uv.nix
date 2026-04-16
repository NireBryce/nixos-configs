{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "uv - python version-, venv-, and packaging-management tool";
      home.packages = with pkgs; [
        uv
      ];
    };
  };
}
