{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # description = "uv - python version-, venv-, and packaging-management tool";
            home.packages = with pkgs; [
              uv
            ];
        };
    };
}
