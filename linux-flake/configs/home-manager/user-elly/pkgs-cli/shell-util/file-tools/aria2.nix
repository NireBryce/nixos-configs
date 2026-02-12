# aria2 -cli download manager
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    aria2
];
in
{
    home.packages = packageList;
}
;}
