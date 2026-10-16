# Module file: named after this file; why it looks this way: wiki/module-files.md
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
