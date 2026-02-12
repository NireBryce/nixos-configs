# desc = "`df` alternative";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    duf
];
in
{
    home.packages = packageList;
}
;}
