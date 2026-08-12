{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # Linux-only: a libratbag/udev frontend, no macOS equivalent.
            # nixpkgs doesn't build it for aarch64-darwin.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
            home.packages = with pkgs; [
                piper
            ];
        };
}
