{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        nix.settings = {
            substituters = [ "https://devenv.cachix.org/" ];
            trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
        };
        environment.systemPackages = with pkgs; [
            devenv
        ];
    };
}
