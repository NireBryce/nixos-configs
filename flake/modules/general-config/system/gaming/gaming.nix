{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            #* steam - (fhs)
            programs.steam = {
                enable = true;
                remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
                # Off 2026-09-26: no host runs a Source dedicated server, and this opened
                # 27015 TCP+UDP on every interface. Uncomment when one does.
                # dedicatedServer.openFirewall = true;
                gamescopeSession.enable = true; # third party gamescope compositor
                localNetworkGameTransfers.openFirewall = true;
                # Installs protontricks overridden with extraCompatPaths. Listing
                # pkgs.protontricks in systemPackages as well (until 2026-09-27)
                # put a second, plain build beside it, both claiming
                # bin/protontricks.
                protontricks.enable = true;
                extraCompatPackages = with pkgs; [
                    steamtinkerlaunch
                ];
            };

            environment.systemPackages = with pkgs; [
                protonup-qt
                mangohud
                steamtinkerlaunch

                # SteamTinkerLaunch needs these and they aren't in the package?
                xxd
                xdotool
                xwininfo
                yad

            ];
        };
}
