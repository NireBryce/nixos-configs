{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # Excluded on darwin because nire/macos/homebrew/homebrew.nix already
            # installs the `obsidian` cask, so lysithea was getting two copies.
            # Same shape and same reason as vicinae.nix, but a weaker failure:
            # this one evaluates fine on aarch64-darwin, it just *builds* badly.
            # pkgs.obsidian on darwin is a repackaged upstream .dmg, and being
            # unfree it is never on cache.nixos.org -- so every build of
            # darwinConfigurations.nire-lysithea fetched Obsidian-<ver>.dmg from
            # GitHub releases directly. On 2026-08-12 that returned 503 through
            # all four of fetchurl's attempts and failed the whole build, for a
            # package the machine was installing twice anyway.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
        # # description = "Obsidian - markdown PKM like org mode, https://obsidian.md/";
            home.packages = with pkgs; [
                obsidian
            ];
        };
}
