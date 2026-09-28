{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # android-tools: Android SDK platform tools (adb, fastboot)
            home.packages = with pkgs; [
                android-tools
            ];
        };
}
