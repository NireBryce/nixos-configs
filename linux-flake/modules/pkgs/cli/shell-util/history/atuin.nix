{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.atuin ];

    flake.modules.homeManager.atuin =
# desc = "Atuin remote encrypted history manager";
{
    programs.atuin = {       
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        settings = {
            inline_height   = 13;       # search window height
            style           = "compact";
            show_preview    = true;
            show_help       = true;
            secrets_filter  = true;
        };
    };
}
;}
