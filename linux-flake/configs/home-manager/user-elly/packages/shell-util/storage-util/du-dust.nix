# desc = "`du` alternative";
{ pkgs, ... }:
let packageList = with pkgs; [
    dust
];
in
{
    home.packages = packageList;
}
