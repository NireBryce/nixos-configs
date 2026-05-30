{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            #* steam - (fhs)
            programs.steam = {
                enable = true;
                remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
                dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
                gamescopeSession.enable = true; # third party gamescope compositor
                localNetworkGameTransfers.openFirewall = true;
                protontricks.enable = true;
                extraCompatPackages = with pkgs; [
                    steamtinkerlaunch
                ];
            };

            environment.systemPackages = with pkgs; [
                protonup-qt
                protontricks
                mangohud
                steamtinkerlaunch

                # SteamTinkerLaunch needs these and they aren't in the package?
                xxd
                xdotool
                xwininfo
                yad

            ];
        };
    };
}
