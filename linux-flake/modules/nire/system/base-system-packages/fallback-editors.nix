{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        environment.systemPackages = with pkgs; [ 
            # Editors
            vim                         # failsafe
            nano                        # backup of a backup, vim is bad on a phone                               https://www.nano-editor.org/
            nanorc                      # nano syntax highlighting  
        ];
    };
}
