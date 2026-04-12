{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "Zoxide - better `cd`";
        programs.zoxide = {      
            enable                  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
            enableFishIntegration   = true;
            # options                 = [ "--cmd x" ]; 
        };    
    };
}
