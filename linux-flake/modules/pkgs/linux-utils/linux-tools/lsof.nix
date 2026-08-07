{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.lsof ];

    flake.modules.homeManager.lsof =
# desc = "list open files https://linux.die.net/man/1/lsof";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        lsof
    ];
}
;}
