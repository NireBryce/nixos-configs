# desc = "system call tracer https://linux.die.net/man/1/strace";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        strace
    ];
}
