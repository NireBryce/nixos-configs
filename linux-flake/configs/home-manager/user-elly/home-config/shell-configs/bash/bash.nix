# desc = "bash configs";
{ pkgs, ... }:

{
    


    programs.bash = {
        enable = true;
        enableCompletion = true;
        enableVteIntegration = true;


        #? Shell integrations go here but main bash config is in the system one.
        sessionVariables = {
        };
        shellAliases = {
        };
        
        
        #? Extra commands that should be run when initializing an interactive shell.
        initExtra = ''



            [[ ''$- == *i* ]] && source -- ${pkgs.blesh}/share/blesh/ble.sh --attach=none
            eval "''$(starship init bash)"
            
            source <(cod init ''$''$ bash)






            [[ ! ''${BLE_VERSION-} ]] || ble-attach
        '';

        # ? Extra commands that should be placed in {file}~/.bashrc.
        # ?   Note that these commands will be run even in non-interactive shells.
        bashrcExtra = ''
        '';

        #? Extra commands that should be run when initializing a login shell.
        profileExtra = ''
        '';
        #? Extra commands that should be run when logging out of an interactive shell.
        logoutExtra = ''
        '';

    };
}
