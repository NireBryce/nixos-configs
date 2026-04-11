{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.nixos = {
        # description = "Cod - Completion daemon";
        # I think it needs to be system installed to access system shells
        environment.systemPackages = with pkgs; [
            cod 
        ];
    };
}
