{ pkgs, ... }:
{
# library call tracer https://linux.die.net/man/1/ltrace
    home.packages = with pkgs; [
        ltrace
    ];
}

