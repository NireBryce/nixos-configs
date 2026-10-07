{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # NixOS's programs.kdeconnect only installs the package and opens the
        # firewall ports (1714-1764 TCP+UDP) -- it starts no daemon. Without a
        # unit, kdeconnectd is D-Bus-activated (org.kde.kdeconnect) when
        # Plasma's applet first asks for it, with no supervision: if it dies
        # (crash, suspend/resume race) nothing restarts it, and the phone sees
        # the device go unreachable and drops the pairing until kdeconnectd
        # happens to come back. Home Manager's services.kdeconnect runs it as a
        # systemd --user unit with Restart=on-abort instead, so it comes back
        # on its own (ordering below). indicator stays off: Plasma's own tray applet
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

                # HM ties the unit to graphical-session.target, which a
                # Gamescope session (tenacity boots into one) reaches with no
                # WAYLAND_DISPLAY/DISPLAY. kdeconnectd then aborts on the Qt
                # xcb plugin, Restart=on-abort retries it into start-limit-hit,
                # and each abort is a coredump that DrKonqi's launcher -- also
                # displayless at that point -- aborts on in turn, looping until
                # Plasma comes up (#471). Started that way the unit never ran
                # kdeconnectd at all: the D-Bus-activated copy owned the name
                # and later starts exited 0. Hang it off Plasma instead, the
                # way plasma-powerdevil.service does: wanted by
                # plasma-workspace.target, after plasma-core.target (itself
                # after plasma-kwin_wayland.service). PartOf stays
                # graphical-session.target, as upstream and Plasma's own units have it.
                systemd.user.services.kdeconnect = {
                    Unit.After = lib.mkForce [ "plasma-core.target" ];
                    Install.WantedBy = lib.mkForce [ "plasma-workspace.target" ];
                };
            };
}
