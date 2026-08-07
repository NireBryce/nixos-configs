{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.rust ];

    flake.modules.homeManager.rust =
### RUST DEV MOVED TO SYSTEM
{    }
;}
