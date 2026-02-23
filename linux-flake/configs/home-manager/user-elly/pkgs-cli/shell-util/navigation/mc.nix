# desc = "midnight commander file browser";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    mc
];

in

{
    home.packages = packageList;
}
;}
