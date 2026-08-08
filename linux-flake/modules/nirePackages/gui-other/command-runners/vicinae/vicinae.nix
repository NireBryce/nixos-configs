{ lib, ... }:

    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "Like raycast for linux";
            programs.vicinae = {
                enable = true;
                systemd = {
                    enable = true;
                    autoStart = true;
                };
            };
        };
}
