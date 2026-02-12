# delta - a better git diff viewer
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    delta
];
in
{
    home.packages = packageList;
}
;}
