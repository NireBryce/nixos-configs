# desc = "library call tracer https://linux.die.net/man/1/ltrace";
{ pkgs, ... }:
let packageList = with pkgs; [
    ltrace
];
in
{
    home.packages = packageList;
}
