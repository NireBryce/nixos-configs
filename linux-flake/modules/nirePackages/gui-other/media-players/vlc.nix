{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # nixpkgs' vlc does not build for aarch64-darwin (meta.platforms
            # excludes it), same class of failure as libre-office.nix and the
            # linux-utils/ packages. The official VLC.app is what people
            # actually use on macOS; add it as a homebrew cask in
            # nire/macos/homebrew/homebrew.nix if wanted on nire-lysithea.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "vlc media player";
            home.packages = with pkgs; [
                vlc
            ];
        };
}
