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

                     # terminal emulator                         https://github.com/wez/wezterm
    # browsers                  # browsers                                # browsers
      
    # comms                     # comms                                   # comms
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
      davinci-resolve
  ];
  # Game stuff managed through system configuration
}

# NOTES:
# - consider moving qpwgraph to headed-server configs too
