{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # A libratbag/udev frontend, so Linux-only with no macOS
            # equivalent; meta.platforms excludes aarch64-darwin.
            # piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper
            home.packages = with pkgs; [
                piper
            ];
        };
}
