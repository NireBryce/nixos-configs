# desc = "home-manager instance of python3";
{ pkgs, ... }:
let packageList = with pkgs; [
    python3
];
in
{
    home.packages = packageList;
}
