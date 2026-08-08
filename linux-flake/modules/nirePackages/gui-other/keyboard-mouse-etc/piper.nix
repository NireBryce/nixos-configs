{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
            home.packages = with pkgs; [
                piper
            ];
        };
}
