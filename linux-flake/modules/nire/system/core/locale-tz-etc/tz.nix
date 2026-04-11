{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        time.timeZone       = lib.mkDefault "America/New_York"; 
    };
}
