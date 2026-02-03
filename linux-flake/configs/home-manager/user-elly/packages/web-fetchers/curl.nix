# desc = "curl https://curl.se/";
{ flake.modules.homeManager.packages.webFetchers.curl =
{ pkgs, ... }:
let packageList = with pkgs; [
    curl
];
in
{
    home.packages = packageList;
}
;}
