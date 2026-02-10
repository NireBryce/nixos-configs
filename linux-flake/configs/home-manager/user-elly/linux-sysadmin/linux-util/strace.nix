# desc = "system call tracer https://linux.die.net/man/1/strace";
{ den.bundles.hm.linux-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    strace
];
in
{
    home.packages = packageList;
}
;}
