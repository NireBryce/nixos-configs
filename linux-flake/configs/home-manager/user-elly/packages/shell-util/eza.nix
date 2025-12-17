# desc = "";
    { ... }:

{
    programs.eza = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        icons = "auto";
        colors = "auto";
        git = true;
        extraOptions = [ 
            "header" 
            "hyperlink" 
            "group-directories-first" 
        ];
    
    };
}

