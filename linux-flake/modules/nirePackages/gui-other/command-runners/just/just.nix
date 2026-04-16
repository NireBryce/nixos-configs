{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "just - justfile runner";
      home.file = {
        "./.justfile".source = ./config/.justfile;
        "./.just/.justfile".source = ./config/.justfile;
        "./.just".source = ./config;
      };

      home.packages = with pkgs; [
        just
      ];
    };
  };
}
