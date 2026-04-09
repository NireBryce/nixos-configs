{
    description = "Zoxide - better `cd`";

    homeManager = {
        programs.zoxide = {      
            enable                  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
            enableFishIntegration   = true;
            # options                 = [ "--cmd x" ]; 
        };    
    };
}
