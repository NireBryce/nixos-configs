# desc = "run commands when file changes";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    entr
];
in
{
    home.packages = packageList;
}
;}
