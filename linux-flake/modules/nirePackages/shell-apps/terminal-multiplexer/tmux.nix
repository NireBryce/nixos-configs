{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { 
        # # description = "tmux - terminal multiplexer";
            programs.tmux = {
                enable = true;
            };
        };
}
