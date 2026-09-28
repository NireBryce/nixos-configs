{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # NixOS's programs.kdeconnect only installs the package and opens the
        # firewall ports (1714-1764 TCP+UDP) -- it starts no daemon. kdeconnectd
        # itself came from Plasma's own autostart .desktop entry, which has no
        # supervision: if it dies (crash, suspend/resume race) nothing restarts
        # it, and the phone sees the device go unreachable and drops the
        # pairing until kdeconnectd happens to come back. Home Manager's
        # services.kdeconnect runs it as a systemd --user unit tied to
        # graphical-session.target with Restart=on-abort instead, so it comes
        # back on its own. indicator stays off: Plasma's own tray applet
        # (org.kde.kdeconnect) already covers that; kdeconnect-indicator is
        # the non-Plasma (e.g. GNOME/gsconnect-adjacent) equivalent.
        flake.modules.nixos.${moduleName} = {
            programs.kdeconnect = {
                enable = true; # package + firewall ports only
            };
        };

        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            # services.kdeconnect asserts meta.platforms (Linux-only), a hard
            # eval failure, and ellyHomeManager is shared with nire-lysithea
            # (aarch64-darwin). The guard has to be here by hand:
            # drop-unsupported-packages.nix only filters home.packages, and
            # services.* assertions fire before any package list exists --
            # same shape as vicinae.nix.
            lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
                services.kdeconnect = {
                    enable = true;
                    indicator = false;
                };
            };
}
