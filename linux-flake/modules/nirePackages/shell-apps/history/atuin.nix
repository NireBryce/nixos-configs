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
    };
}
