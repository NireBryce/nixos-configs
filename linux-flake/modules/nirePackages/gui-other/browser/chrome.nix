{ lib, ... }:
    let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # Same reason as obsidian.nix and discord.nix, and read the
            # isDarwin test the same way: "on darwin, homebrew.nix owns this
            # app", NOT "Linux-only". google-chrome builds on aarch64-darwin,
            # and homebrew.nix installs the `google-chrome` cask, so lysithea
            # was getting two copies.
            #
            # Excluded rather than left alone because google-chrome is unfree,
            # so it is never on cache.nixos.org and every darwin build fetches
            # it from upstream -- the shape that failed the whole build with a
            # GitHub 503 on obsidian, 2026-08-12.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # note: this is also installed as a system package, does that matter?
            home.packages = with pkgs; [
                google-chrome
            ];
        };
}
