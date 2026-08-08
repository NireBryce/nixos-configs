{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
          # # description = "jq https://github.com/stedolan/jq";
            home.packages = with pkgs; [
                jq
            ];
        };
}
