# desc = "`diff` utils";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    diffutils
];
in
{
    home.packages = packageList;
}
;}
