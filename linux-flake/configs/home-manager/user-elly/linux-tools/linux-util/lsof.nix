# desc = "list open files https://linux.die.net/man/1/lsof";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    lsof
];
in
{
    home.packages = packageList;
}
;}
