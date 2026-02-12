# desc = "`du` alternative";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    dust
];
in
{
    home.packages = packageList;
}
;}
