# desc = "Teamspeak 3";
{ pkgs, ... }:
let packageList = with pkgs; [
    teamspeak3
];
in
{
    home.packages = packageList;
}


# Potentially useful dead code:
        # programs.teamspeak3 = {
        #     enable = true;
        #     teamspeak3.override {
        #       ts3Plugins = [ teamspeak-pluginsdk.test_plugin ];
        #     }
        # };

