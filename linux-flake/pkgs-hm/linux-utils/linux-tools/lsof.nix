# desc = "list open files https://linux.die.net/man/1/lsof";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        lsof
    ];
}

