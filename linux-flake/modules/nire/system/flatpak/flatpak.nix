{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            services.flatpak.enable = true;
            systemd.services.flatpak-repo = {
                wantedBy = [ "multi-user.target" ];
                path = [ pkgs.flatpak ];

                # RequiresMountsFor, because /var/lib/flatpak is an impermanence
                # bind mount from /persist -- see WARN-impermanence.nix. Without
                # it this can run against an empty directory and re-add a remote
                # that already exists. It happened to be ordered correctly on
                # 2026-08-11 (mount 15:20:58, unit 15:20:59), but by luck.
                unitConfig.RequiresMountsFor = "/var/lib/flatpak";

                # The guard is the point. `remote-add --if-not-exists` fetches
                # the .flatpakrepo file *before* deciding whether the remote
                # exists, so it needs the network even when there is nothing to
                # do -- and this unit starts about four seconds into boot, well
                # before DNS. It failed on every boot in the journal:
                #
                #   error: Can't load uri https://flathub.org/repo/flathub.flatpakrepo:
                #   [6] Could not resolve hostname
                #
                # while /var/lib/flatpak/repo/config, which is persisted, dates
                # from 2025-12-14. Purely cosmetic, but a permanently failed
                # unit is noise that hides real ones.
                #
                # Checking first makes the normal case need no network at all.
                #
                # Deliberately NOT `wants = [ "network-online.target" ]`: nothing
                # on this host currently pulls that target up, so wanting it
                # would add NetworkManager-wait-online to every boot of a
                # handheld that is often offline, to fix a case that only arises
                # on a fresh install. If the remote is ever genuinely missing and
                # the machine boots offline, this still fails -- run
                # `systemctl start flatpak-repo` once there is a network.
                script = ''
                    flatpak remotes --system --columns=name | grep -qx flathub \
                        || flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo
                '';
            };
        };
}
