{ pkgs, ... }:
{
# list open files https://linux.die.net/man/1/lsof
    home.packages = with pkgs; [
        lsof
    ];
}

