# desc = "library call tracer https://linux.die.net/man/1/ltrace";
{ den.bundles.hm.linux-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    ltrace
];
in
{
    home.packages = packageList;
}
;}
