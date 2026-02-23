# desc = "curl https://curl.se/";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    curl
];
in
{
    home.packages = packageList;
}
;}
