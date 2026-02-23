# desc = "jq https://github.com/stedolan/jq";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    jq
];
in
{
    home.packages = packageList;
}
;}
