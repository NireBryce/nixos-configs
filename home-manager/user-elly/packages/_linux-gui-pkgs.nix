{ pkgs, ...}:

{

  # programs.teamspeak_client = {              # teamspeak game comms                      https://www.teamspeak.com/
  # enable = true;
  #     # teamspeak_client.override {
  #     #   ts3Plugins = [ teamspeak-pluginsdk.test_plugin ];
  #     # }
  # };
  programs.obs-studio = {
    enable = true;                  # screen recording / streaming         https://obsproject.com/
    plugins = with pkgs; [ 
      obs-studio-plugins.obs-vaapi  # enables AMD hardware accel?
    ];
  };
  home.packages = with pkgs; [ 

    # terminals                 # terminals                                 # terminals
      kitty                         # gpu accelerated terminal                  https://sw.kovidgoyal.net/kitty
      kitty-img                     # kitty image rendering engine, like sixel  https://git.sr.ht/~zethra/kitty-img
      wezterm                       # terminal emulator                         https://github.com/wez/wezterm
    # browsers                  # browsers                                # browsers
      firefox                       # TODO: also installed as a system package. https://www.mozilla.org/en-US/firefox/

    # comms                     # comms                                   # comms
      # cinny-desktop                 # matrix client                             https://github.com/cinnyapp/cinny-desktop
        # TODO: waiting on libolm fix
      bitwarden                     # password manager                          https://bitwarden.com/
      discord                       # discord chat                              https://discord.com/
      # keybase-gui                   # encrypted chat almost no one uses         https://keybase.io/
      # keybase                       # see above                                 https://keybase.io/
      teamspeak_client              # voice chat                                https://www.teamspeak.com/
      zoom-us                       # less features than facetime somehow       https://zoom.us/
    # editors                   # editors                                   # editors
      vscode-fhs                    # vscode                                    https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/editors/vscode/
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

      audacity
  ];
  # Game stuff managed through system configuration
}

# NOTES:
# - consider moving qpwgraph to headed-server configs too
