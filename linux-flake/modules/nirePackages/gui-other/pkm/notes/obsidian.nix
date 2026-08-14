{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # Excluded on darwin because nire/macos/homebrew/homebrew.nix already
            # installs the `obsidian` cask, so lysithea was getting two copies.
            #
            # Same SHAPE as vicinae.nix and the linux-utils modules, but NOT the
            # same reason, and the difference is the point. Those are guards
            # around packages nixpkgs cannot build here at all -- without them
            # the host does not evaluate. This one builds on aarch64-darwin
            # perfectly well:
            #
            #     just available obsidian     ->  available, cask obsidian
            #     just available vlc          ->  unsupported
            #
            # It is excluded because the machine does not need two, and because
            # the nix copy is the expensive one: pkgs.obsidian on darwin is a
            # repackaged upstream .dmg, and being unfree it is never on
            # cache.nixos.org, so every build of darwinConfigurations.
            # nire-lysithea fetched Obsidian-<ver>.dmg from GitHub directly. On
            # 2026-08-12 that returned 503 through all four of fetchurl's
            # attempts and failed the whole build, for an app Homebrew had
            # already installed.
            #
            # Do not read the isDarwin test here as "this is Linux-only". It
            # means "on darwin, homebrew.nix owns this app".
            lib.mkIf (!pkgs.stdenv.isDarwin) {
        # Obsidian - markdown PKM like org mode, https://obsidian.md/
            home.packages = with pkgs; [
                obsidian
            ];
        };
}
