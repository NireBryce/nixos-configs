{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.tmux ];

    flake.modules.homeManager.tmux =
# desc = "";
{
    programs.tmux = {
        enable = true;
    };
}
;}
