# vivid - LS_COLORS generator
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    vivid
];
in
{
    home.packages = packageList;
}
;}
