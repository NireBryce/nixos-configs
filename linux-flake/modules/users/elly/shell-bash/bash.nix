{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.elly-shell-bash ];

    flake.modules.homeManager.elly-shell-bash = 
{ pkgs, ... }:

{
    # blesh and .blerc are owned by shell-bash/blesh.nix. This file used to
    # declare both as well, and since home.file.<n>.text is types.lines the two
    # definitions concatenated -- the generated .blerc ran every ble-import twice.
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

            # starship is NOT initialised here: programs.starship.enableBashIntegration
            # (pkgs/cli/shell-util/appearance-cli/starship.nix) already emits an init
            # later in this file, using the store path rather than bare `starship`.
            # Doing it here as well ran it twice.

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
};

}
