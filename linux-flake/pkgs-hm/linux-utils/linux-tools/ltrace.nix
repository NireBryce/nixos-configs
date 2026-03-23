# desc = "library call tracer https://linux.die.net/man/1/ltrace";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ltrace
    ];
}

