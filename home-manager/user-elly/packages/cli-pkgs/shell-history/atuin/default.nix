{
    ...
}:
 
{
    imports = [
        
    ];
    programs.atuin = {       
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        settings = {
            inline_height   = 10;       # search window height
            style           = "compact";
            show_preview    = true;
            show_help       = true;
            secrets_filter  = true;
        };
    }; 
}
