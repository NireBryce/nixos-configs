{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # promnesia breadcrumb-bookmarks-and-more
            home.file.".config/promnesia".source = ./config/config.py;
        };
}
