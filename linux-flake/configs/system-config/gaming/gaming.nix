{
    ...
}:
{ den.aspects.nixos.provides.gaming = 
{pkgs, ...}: 
{
    #* steam - (fhs)
    programs.steam = {
        enable = true;
        remotePlay.openFirewall                 = true;     # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall            = true;     # Open ports in the firewall for Source Dedicated Server
        gamescopeSession.enable                 = true;     # third party gamescope compositor
        localNetworkGameTransfers.openFirewall  = true;
        protontricks.enable                     = true;
        extraCompatPackages = with pkgs; [ 
            steamtinkerlaunch
        ];
    };

    environment.systemPackages = with pkgs; [
        protonup-qt 
        protontricks
        mangohud
        steamtinkerlaunch
        # TODO: SteamTinkerLaunch needs these and they aren't in the package?
        xxd
        xdotool
        xorg.xwininfo
        yad           
        wineWowPackages.waylandFull # Wine for wayland                          https://www.winehq.org/
    ];
}
;}
