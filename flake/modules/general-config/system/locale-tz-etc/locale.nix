{ lib, ... }:
    let
          moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
    flake.modules.nixos.${moduleName} = {
            i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
        };
}
