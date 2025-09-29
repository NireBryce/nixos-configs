# desc = "curl https://curl.se/";
{ pkgs, ... }:
let packageList = with pkgs; [
    curl
];
in
{
    home.packages = packageList;
}
