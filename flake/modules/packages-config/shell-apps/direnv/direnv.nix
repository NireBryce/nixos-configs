# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ 
    homeManager = {
        programs.direnv = {
            enable = true;
            enableBashIntegration = true;
            enableZshIntegration = true;
            enableNushellIntegration = true;
            nix-direnv.enable = true;
        };
    };
}
