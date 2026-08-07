{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.strace ];

    flake.modules.homeManager.strace =
# desc = "system call tracer https://linux.die.net/man/1/strace";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        strace
    ];
}
;}
