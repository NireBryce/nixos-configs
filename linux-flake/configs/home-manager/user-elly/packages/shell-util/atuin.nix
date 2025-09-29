# desc = "Atuin remote encrypted history manager";
{ ... }:
{
    programs.atuin = {       
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        settings = {
            inline_height   = 13;       # search window height
            style           = "compact";
            show_preview    = true;
            show_help       = true;
            secrets_filter  = true;
        };
    };
}
