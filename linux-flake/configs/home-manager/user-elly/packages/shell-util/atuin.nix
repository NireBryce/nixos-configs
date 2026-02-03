# desc = "Atuin remote encrypted history manager";
{ flake.modules.homeManager.packages.shellUtil.history.atuin = 
{ ... }:
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
