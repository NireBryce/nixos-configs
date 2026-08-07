{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.ltrace ];

    flake.modules.homeManager.ltrace =
# desc = "library call tracer https://linux.die.net/man/1/ltrace";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ltrace
    ];
}
;}
