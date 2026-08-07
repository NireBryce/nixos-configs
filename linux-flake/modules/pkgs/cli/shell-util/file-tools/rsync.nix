{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.rsync ];

    flake.modules.homeManager.rsync =
# rsync - back in my day we transfered our files uphill both ways
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        rsync
    ];
}
;}
