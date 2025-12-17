# desc = "";
    { ... }:

{
    programs.eza = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        defaultOptions = [ 
            "icons" 
            "header" 
            "hyperlink" 
            "group-directories-first" 
        ];
        
    };
}

