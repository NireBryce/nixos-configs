# yazi - file browser MAKE BETTER DESC
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    yazi
];
in
{
    home.packages = packageList;
}
;}
