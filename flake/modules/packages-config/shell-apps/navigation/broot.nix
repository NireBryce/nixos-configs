# Module file: named after this file; why it looks this way: wiki/module-files.md
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
