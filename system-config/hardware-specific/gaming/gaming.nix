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

    # handhelds
    jovian.steam.enable = true;
    jovian.decky-loader.enable = true;
    #  $ touch ~/.steam/steam/.cef-enable-remote-debugging  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/460#issuecomment-2599835660


    services.handheld-daemon = {
      # if you're coming here from github search looking for ways to make HHD work,
      #     I need you to understand that the TDP control is currently mired in nixpkgs
      #     if you want it to work, it needs some work that I cannot do.
      enable = true;
      user = "elly";
      ui.enable = true;
    };

    environment.systemPackages = with pkgs; [
          #* games                     
        lutris                      # lutris game launcher                      https://lutris.net/
        # steam                     # see below                                 https://github.com/NixOS/nixpkgs/blob/stable/pkgs/applications/games/steam/steam.nix
        protonup-qt                 # proton installer/updater                  https://davidotek.github.io/protonup-qt/
        protontricks                # protontricks                              https://github.com/Matoking/protontricks
        wineWowPackages.waylandFull # Wine for wayland                          https://www.winehq.org/
        steamtinkerlaunch           # steamtinkerlaunch                         https://github.com/sonic2kk/steamtinkerlaunch
    ];
  #* fix steamtinkerlaunch compatability tool breaking on system rebuild
  # TODO: it doesnt really work as far as I can tell, bug is still there
    environment.shellAliases = {
        # https://gist.github.com/jakehamilton/632edeb9d170a2aedc9984a0363523d3
        steamtinkerlaunch-compataddfix = "mkdir -p $STEAM_EXTRA_COMPAT_TOOL_PATHS/SteamTinkerLaunch && ln -s /run/current-system/sw/bin/steamtinkerlaunch $STEAM_EXTRA_COMPAT_TOOL_PATHS/SteamTinkerLaunch/steamtinkerlaunch"; 
    };
}
