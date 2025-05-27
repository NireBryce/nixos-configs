{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
      bitwarden                     # password manager                          https://bitwarden.com/
      discord                       # discord chat                              https://discord.com/
      # keybase-gui                   # encrypted chat almost no one uses         https://keybase.io/
      # keybase                       # see above                                 https://keybase.io/
      teamspeak_client              # voice chat                                https://www.teamspeak.com/
      zoom-us                       # less features than facetime somehow       https://zoom.us/
    ];

    # programs.teamspeak_client = {              # teamspeak game comms                      https://www.teamspeak.com/
    #     enable = true;
    #     teamspeak_client.override {
    #       ts3Plugins = [ teamspeak-pluginsdk.test_plugin ];
    #     }
    # };
}
