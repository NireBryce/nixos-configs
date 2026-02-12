# desc = "curl https://curl.se/";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    curl
];
in
{
    home.packages = packageList;
}
;}
