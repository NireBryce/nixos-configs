# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { 
        # `exa` fork, which is an ls alternative
        programs.eza = {
            enable = true;
            enableZshIntegration = true;
            enableBashIntegration = true;
            enableFishIntegration = true;
            icons = "auto";
            colors = "auto";
            git = true;
            extraOptions = [
            "-1" # portrait mode
            "--header"
            "--hyperlink"
            "--group-directories-first"
            ];
        };
    };
}
