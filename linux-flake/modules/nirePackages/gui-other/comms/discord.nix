{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # Same reason as obsidian.nix, and read the isDarwin test the same
            # way: "on darwin, homebrew.nix owns this app", NOT "Linux-only".
            # discord builds on aarch64-darwin perfectly well, and
            # homebrew.nix installs the `discord` cask, so lysithea was
            # getting two copies.
            #
            # Excluded rather than left alone because discord is unfree, so it
            # is never on cache.nixos.org and every darwin build fetches it
            # from upstream -- the exact shape that failed the whole build with
            # a GitHub 503 on obsidian, 2026-08-12. audacity and firefox are
            # the other two duplicates and were left alone: both are free and
            # come from the cache, so they cost build time rather than
            # risking the build.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "discord gamer chat app that broke containment";
            home.packages = with pkgs; [
                discord
            ];
        };
}
