# desc = "count lines of code";
{ pkgs, ... }:
let packageList = with pkgs; [
    tokei
];
in
{
    home.packages = packageList;
}
