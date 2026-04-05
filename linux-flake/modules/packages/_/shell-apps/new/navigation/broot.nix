{
    description = "`tree` alternative";
    
    homeManager =
    {
        programs.broot = {
            enable  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
            enableFishIntegration   = true;
        };

    };
}
