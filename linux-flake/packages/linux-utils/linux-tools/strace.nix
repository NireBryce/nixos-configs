{ pkgs, ... }:
{
# system call tracer https://linux.die.net/man/1/strace
    home.packages = with pkgs; [
        strace
    ];
}
