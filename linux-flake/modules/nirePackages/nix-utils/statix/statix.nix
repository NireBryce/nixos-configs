{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # # description = "nix antipattern linter";
            home.packages = with pkgs; [
                statix
            ];
        };
}
