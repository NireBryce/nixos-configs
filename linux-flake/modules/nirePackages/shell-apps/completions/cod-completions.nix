{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = { pkgs, ... }:
        # description = "Cod - Completion daemon";
        # I think it needs to be system installed to access system shells
        environment.systemPackages = with pkgs; [
            cod 
        ];
    };
}
