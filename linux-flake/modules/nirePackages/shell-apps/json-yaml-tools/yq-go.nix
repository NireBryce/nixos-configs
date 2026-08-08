{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # # description = "yaml jq https://github.com/mikefarah/yq";
            home.packages = with pkgs; [
                yq-go
            ];
        };
}
