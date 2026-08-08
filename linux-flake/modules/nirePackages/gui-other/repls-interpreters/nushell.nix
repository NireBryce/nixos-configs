{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # nushell - the next generation shell
        # hint: nushell -c for tabular display in any shell
            home.packages = with pkgs; [
                nushell
            ];
        };
}
