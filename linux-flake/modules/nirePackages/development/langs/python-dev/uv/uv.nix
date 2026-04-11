{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.development._.${moduleName}.homeManager = {        # description = "uv - python version-, venv-, and packaging-management tool";
        home.packages = with pkgs; [
            uv
        ];
    };
}
