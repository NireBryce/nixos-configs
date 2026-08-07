{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.fd ];

    flake.modules.homeManager.fd =
# desc = "`find` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        fd
    ];
}
;}
