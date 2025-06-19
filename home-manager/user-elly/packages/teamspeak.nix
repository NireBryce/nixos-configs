{ ... }:
{
    # desc = "Teamspeak 3";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        teamspeak_client
    ];
    in
    {
        home.packages = packageList;
    };

}


# Potentially useful dead code:
        # programs.teamspeak_client = {
        #     enable = true;
        #     teamspeak_client.override {
        #       ts3Plugins = [ teamspeak-pluginsdk.test_plugin ];
        #     }
        # };

