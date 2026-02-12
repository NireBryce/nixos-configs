# vivid - LS_COLORS generator
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    vivid
];
in
{
    home.packages = packageList;
}
;}
