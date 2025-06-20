# desc = "list open files https://linux.die.net/man/1/lsof";
{ pkgs, ... }:
let packageList = with pkgs; [
    lsof
];
in
{
    home.packages = packageList;
}
