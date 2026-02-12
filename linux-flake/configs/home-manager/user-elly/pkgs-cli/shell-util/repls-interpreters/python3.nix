# desc = "home-manager instance of python3";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    python3
];
in
{
    home.packages = packageList;
}
;}
