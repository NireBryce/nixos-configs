{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # # description = "uv - python version-, venv-, and packaging-management tool";
        home.packages = with pkgs; [
            uv
        ];
    };
}
