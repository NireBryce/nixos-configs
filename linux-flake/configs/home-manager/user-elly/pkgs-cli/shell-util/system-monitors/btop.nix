# desc = "`htop` alternative";
{ pkgs, ... }:
{ den.aspects.hm.provides.pkgs-cli = 
let packageList = with pkgs; [
    btop
];
in
{
    home.packages = packageList;
}
;}
