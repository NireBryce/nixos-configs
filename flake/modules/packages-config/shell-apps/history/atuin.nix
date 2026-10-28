# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = {
    # Atuin remote encrypted history manager. History syncs to the remote
    # sync server by default (auto_sync, on every prompt) -- nothing here
    # disables it, deliberately; the account and its rotation runbook are
    # atuin-key-rotation.md, next to this file.
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
