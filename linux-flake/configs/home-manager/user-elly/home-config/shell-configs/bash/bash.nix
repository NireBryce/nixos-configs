# desc = "bash configs";
{ pkgs, ... }:

{
    

    home.file = {
        "./.bash_logout"      .source = ./config/.bash_logout;
        "./.bash_profile"     .source = ./config/.bash_profile;
        "./.bashrc"           .source = ./config/.bashrc;
        "./.profile"          .source = ./config/.profile;
    };
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
            [[ $- == *i* ]] && source -- ${pkgs.blesh}/share/blesh/ble.sh --attach=none
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
