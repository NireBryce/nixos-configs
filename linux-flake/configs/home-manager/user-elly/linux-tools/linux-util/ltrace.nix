# desc = "library call tracer https://linux.die.net/man/1/ltrace";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ltrace
];
in
{
    home.packages = packageList;
}
;}
