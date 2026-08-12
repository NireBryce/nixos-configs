{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # nixpkgs' github-desktop is a Linux-only Electron build;
            # meta.platforms excludes aarch64-darwin. The official GitHub
            # Desktop app is what people actually use on macOS; add it as a
            # homebrew cask in nire/macos/homebrew/homebrew.nix if wanted on
            # nire-lysithea.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            home.packages = with pkgs; [
                github-desktop
            ];
        };
}
