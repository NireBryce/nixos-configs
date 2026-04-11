{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.nix-utils._.${moduleName}.homeManager = {
        programs.nh = {
            enable          = true;
            clean.enable    = true;
            clean.extraArgs = "--keep-since 7d --keep 5";
            # flake           = "/home/elly/nixos"; # TODO: see if this can be dynamically set to this flake's path
        };
    };
}

