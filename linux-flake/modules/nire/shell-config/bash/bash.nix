{ lib, pkgs, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName} = {
        nixos = {
            environment.pathsToLink = [
                "/share/bash-completion"
            ];
            environment.shells = with pkgs; [
                bash
            ];
        };

        homeManager = {
            # bash line editor, allows zsh-like line editor tricks and bindings
            home.packages = with pkgs; [
                blesh
            ];
            home.file.".blerc".text = ''
                bleopt complete_menu_style=desc

                bleopt menu_desc_multicolumn_width=

                # Note: If you would like to combine fzf-completion with bash_completion, you
                # need to load bash_completion earlier than fzf-completion.

                # source ${pkgs.bash-completion}/etc/bash_completion

                _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf

                # Set up fzf
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-completion.bash
                ble-import -d ${pkgs.blesh}/share/blesh/contrib/integration/fzf-key-bindings.bash
            '';
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
        };
    };
}
