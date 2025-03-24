{
    pkgs,
    ...
}:

{
    #* steam - (fhs)
    programs.steam = {
        enable = true;
        remotePlay.openFirewall      = true;            # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true;            # Open ports in the firewall for Source Dedicated Server
        gamescopeSession.enable      = true;            # third party gamescope compositor
    };

    environment.systemPackages = with pkgs; [
        steamtinkerlaunch           # steamtinkerlaunch                         https://github.com/sonic2kk/steamtinkerlaunch
        protonup-qt                 # proton installer/updater                  https://davidotek.github.io/protonup-qt/
        protontricks                # protontricks                              https://github.com/Matoking/protontricks
    ];

}
