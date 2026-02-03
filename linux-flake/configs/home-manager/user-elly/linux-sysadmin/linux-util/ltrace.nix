# desc = "library call tracer https://linux.die.net/man/1/ltrace";
{ flake.modules.homeManager.commonLinux.linuxUtil.ltrace =
{ pkgs, ... }:
let packageList = with pkgs; [
    ltrace
];
in
{
    home.packages = packageList;
}
;}
