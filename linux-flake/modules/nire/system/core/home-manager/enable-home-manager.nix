{ inputs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        imports = [
            inputs.home-manager.nixosModules.home-manager
        ];
    };
}
