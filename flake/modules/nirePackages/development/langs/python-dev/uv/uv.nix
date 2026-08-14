{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # description = "uv - python version-, venv-, and packaging-management tool";
            home.packages = with pkgs; [
              uv
            ];
        };
}
