# desc = "cli download manager";
{ pkgs, ... }:
let packageList = with pkgs; [
    aria2
];
in
{
    home.packages = packageList;
}
