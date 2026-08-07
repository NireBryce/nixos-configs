{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.espanso ];

    flake.modules.homeManager.espanso =
# espanso is a text expansion tool that turns a trigger phrase into text
{
    services.espanso = {
        enable  = true;
        waylandSupport = true;
    };
}
;}
