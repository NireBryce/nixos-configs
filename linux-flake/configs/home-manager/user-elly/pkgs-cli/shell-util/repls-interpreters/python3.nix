# desc = "home-manager instance of python3";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    python3
];
in
{
    home.packages = packageList;
}
;}
