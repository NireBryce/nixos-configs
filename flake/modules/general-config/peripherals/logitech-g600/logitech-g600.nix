{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.ratbagd.enable = true; # for piper logitech mouse ctl
        };
}
