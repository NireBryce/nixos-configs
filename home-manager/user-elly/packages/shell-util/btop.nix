# desc = "`htop` alternative";
{ pkgs, ... }:
let packageList = with pkgs; [
    btop
];
in
{
    home.packages = packageList;
}
