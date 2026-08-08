{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.pathsToLink = [
            "/share/bash-completion"
            ];
            environment.shells = with pkgs; [
            bash
            ];
        };
        
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # bash line editor, allows zsh-like line editor tricks and bindings
            home.packages = with pkgs; [
                blesh
            ];
            # .blerc is owned by blesh.nix; this file used to declare a
            # byte-identical copy, which concatenated rather than overrode.

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

                    source <(cod init ''$''$ bash)
                    [[ ! ''${BLE_VERSION-} ]] || ble-attach
                '';
                # ? Extra commands that should be placed in {file}~/.bashrc.
                # ?   Note that these commands will be run even in non-interactive shells.
                bashrcExtra = '''';
                #? Extra commands that should be run when initializing a login shell.
                profileExtra = '''';
                #? Extra commands that should be run when logging out of an interactive shell.
                logoutExtra = '''';
            };
        };
}
