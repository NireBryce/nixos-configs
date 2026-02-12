# desc = "Atuin remote encrypted history manager";
{ den.bundles.hm.shell-util =
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
