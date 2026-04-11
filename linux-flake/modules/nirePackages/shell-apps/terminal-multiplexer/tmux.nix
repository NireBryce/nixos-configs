{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "tmux - terminal multiplexer";
        programs.tmux = {
            enable = true;
        };
    };
}
