# desc = "";
{ den.bundles.hm.shell-util =
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
            "-1"                        # portrait mode
            "--header" 
            "--hyperlink" 
            "--group-directories-first" 
        ];
    
    };
}
;}
