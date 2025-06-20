# desc = "`du` alternative";
{ pkgs, ... }:
let packageList = with pkgs; [
    du-dust
];
in
{
    home.packages = packageList;
}
