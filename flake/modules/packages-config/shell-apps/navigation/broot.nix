# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { 
        # `tree` alternative
        programs.broot = {
            enable = true;
            enableZshIntegration = true;
            enableBashIntegration = true;
            enableFishIntegration = true;
        };
    };
}
