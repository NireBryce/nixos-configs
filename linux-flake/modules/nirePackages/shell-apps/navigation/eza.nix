{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser {
    homeManager =
    { ... }:
    {
      # # description = "`exa` fork, which is an ls alternative";
      programs.eza = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        icons = "auto";
        colors = "auto";
        git = true;
        extraOptions = [
          "-1" # portrait mode
          "--header"
          "--hyperlink"
          "--group-directories-first"
        ];
      };
    };};
}
