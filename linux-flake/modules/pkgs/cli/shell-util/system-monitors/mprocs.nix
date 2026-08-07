{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.mprocs ];

    flake.modules.homeManager.mprocs =
# desc = "run multiple commands in parallel";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        mprocs
    ];
}
;}
