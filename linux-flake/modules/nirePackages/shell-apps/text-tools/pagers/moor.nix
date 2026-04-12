{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
    description = "better pager for some things https://github.com/walles/moor";
        home.packages = with pkgs; [
            moor # moar renamed to moor https://github.com/walles/moor/pull/305
        ];
    };
}
