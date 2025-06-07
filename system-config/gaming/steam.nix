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
        extraCompatPackages = [ "steamtinkerlaunch" "protonup-qt" "protontricks" ];
    };

    environment.systemPackages = with pkgs; [
        # TODO: SteamTinkerLaunch needs these and they aren't in the package?
        xxd
        xdotool
        xorg.xwininfo
        yad
    ];

    # todo: fix steamtinkerlaunch
    #* fix steamtinkerlaunch compatability tool
    # systemd.services.fixSteamTinkerLaunchComaptLink = {
    #     enable = true;
    #     after = [ "network.target" ];
    #     wantedBy = [ "multi-user.target" ];
    #     description = "fix steamtinkerlaunch compatability issues with either nixos or impermaence, unsure which";
    #     serviceConfig = {
    #         Type = "oneshot";
    #         ExecStart = "mkdir -p $STEAM_EXTRA_COMPAT_TOOL_PATHS/SteamTinkerLaunch && ln -s /run/current-system/sw/bin/steamtinkerlaunch $STEAM_EXTRA_COMPAT_TOOL_PATHS/SteamTinkerLaunch/steamtinkerlaunch";
    #         # https://gist.github.com/jakehamilton/632edeb9d170a2aedc9984a0363523d3
    #     };
    # };
}
