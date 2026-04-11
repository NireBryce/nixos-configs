{  lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        i18n.defaultLocale  = lib.mkDefault "en_US.UTF-8";
    };
}
