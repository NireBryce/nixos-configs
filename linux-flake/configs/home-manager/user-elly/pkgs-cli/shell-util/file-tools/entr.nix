# desc = "run commands when file changes";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    entr
];
in
{
    home.packages = packageList;
}
;}
