# desc = "system call tracer https://linux.die.net/man/1/strace";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    strace
];
in
{
    home.packages = packageList;
}
;}
