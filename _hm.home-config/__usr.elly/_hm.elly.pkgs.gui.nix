{ pkgs, ...}:

{
  programs.obs-studio = {
    enable = true;                  # screen recording / streaming         https://obsproject.com/
    plugins = with pkgs; [ 
      obs-studio-plugins.obs-vaapi  # enables AMD hardware accel
    ];
  };
  # vscode-fhs, terminal emulators, and  
  home.packages = with pkgs; [ 
    # browsers                    # browsers                                # browsers
      kdePackages.konqueror         # one of the best `info` file pagers        https://invent.kde.org/network/konqueror
      firefox                       # TODO: also installed as a system package. https://www.mozilla.org/en-US/firefox/

    # comms                       # comms                                   # comms
      cinny-desktop                 # matrix client                             https://github.com/cinnyapp/cinny-desktop
      discord                       # discord chat                              https://discord.com/
      keybase-gui                   # encrypted chat almost no one uses         https://keybase.io/
      keybase                       # see above                                 https://keybase.io/

      signal-desktop                # encrypted chat everone uses               https://signal.org/
      teamspeak_client              # teamspeak game comms                      https://www.teamspeak.com/
      wire-desktop                  # old encrypted chat client, my ex used it  https://wire.com/
      zoom-us                       # less features than facetime somehow       https://zoom.us/

    # games                     # games                                     # games
      lutris                        # lutris game launcher                      https://lutris.net/
      # steam                       # in nix config                             https://github.com/NixOS/nixpkgs/blob/stable/pkgs/applications/games/steam/steam.nix
      protonup-qt                   # proton installer/updater                  https://davidotek.github.io/protonup-qt/
      protontricks                  # protontricks                              https://github.com/Matoking/protontricks
      wineWowPackages.waylandFull   # Wine for wayland                          https://www.winehq.org/
      steamtinkerlaunch             # steamtinkerlaunch                         https://github.com/sonic2kk/steamtinkerlaunch
    # Home                      # Home                                      # Home
      # grocy                         # grocy                                     https://www.grocy.info/
    # media and sound           # media and sound                           # media and sound
      gimp                          # GNU Image Manipulation Program.           https://www.gimp.org
      vlc                           # video player                              https://www.videolan.org/vlc/
      qpwgraph                      # sound mixer                               https://github.com/rncbc/qpwgraph

    # git                       # git                                       # git
      github-desktop                # github-desktop                            https://desktop.github.com/

    # keyboard/mouse/text       # keyboard/mouse/text                       # keyboard/mouse/text
      qmk                           # qmk keyboard manager                      https://github.com/qmk/qmk_firmware
      piper                         # logitech/razer mouse manager              https://github.com/soxoj/piper

    # productivity              # productivity                              # productivity
      obsidian                      # pkm                                       https://obsidian.md/
      libreoffice-qt                # office                                    https://www.libreoffice.org/

  ];
}
