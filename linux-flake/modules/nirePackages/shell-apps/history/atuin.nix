{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { ... }:
    {
      # # description = "Atuin remote encrypted history manager";
      programs.atuin = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        settings = {
          inline_height = 13; # search window height
          style = "compact";
          show_preview = true;
          show_help = true;
          secrets_filter = true;
        };
      };
    };
}
