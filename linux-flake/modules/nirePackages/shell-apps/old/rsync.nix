{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "rsync - back in my day we transfered our files uphill both ways";
        home.packages = with pkgs; [
            rsync
        ];
    };
}
