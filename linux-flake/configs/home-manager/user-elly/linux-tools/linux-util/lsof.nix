# desc = "list open files https://linux.die.net/man/1/lsof";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    lsof
];
in
{
    home.packages = packageList;
}
;}
