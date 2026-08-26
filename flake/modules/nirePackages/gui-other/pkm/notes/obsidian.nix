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

            # KDE/KWin on native Wayland has no protocol for a client to hand
            # the compositor a window icon (unlike X11's _NET_WM_ICON) -- it
            # resolves the taskbar/window-list icon purely by matching the
            # window's app_id string against an installed .desktop file's
            # name. Obsidian's Electron process reports its app_id as
            # `md.Obsidian` (confirmed via a KWin script dumping
            # resourceClass/desktopFileName on nire-tenacity, 2026-08-26 --
            # Obsidian was already running with --ozone-platform=wayland in
            # its real cmdline, so this is NOT an Xwayland problem, it's a
            # Wayland-only one), but nixpkgs ships the desktop file as
            # `obsidian.desktop`. No file named `md.Obsidian.desktop` exists
            # anywhere in XDG_DATA_DIRS, so KWin's lookup fails and the
            # window falls back to a generic placeholder icon. This symlinks
            # an alias so the app_id KWin actually sees has something to
            # match. Confirmed fixing it live on nire-tenacity the same day,
            # by hand first (a plain copy under
            # ~/.local/share/applications/, then `kbuildsycoca6
            # --noincremental`) before being made declarative here.
            home.file.".local/share/applications/md.Obsidian.desktop".source =
                "${pkgs.obsidian}/share/applications/obsidian.desktop";
        };
}
