# desc = "system call tracer https://linux.die.net/man/1/strace";
{ flake.modules.homeManager.commonLinux.linuxUtil.strace =
{ pkgs, ... }:
let packageList = with pkgs; [
    strace
];
in
{
    home.packages = packageList;
}
;}
