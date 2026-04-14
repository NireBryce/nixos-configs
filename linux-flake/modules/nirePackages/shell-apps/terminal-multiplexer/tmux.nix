{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { ... }: {
        # # description = "tmux - terminal multiplexer";
        programs.tmux = {
            enable = true;
        };
    };
}
