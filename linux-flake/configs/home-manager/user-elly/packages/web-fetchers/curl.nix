# desc = "curl https://curl.se/";
{ den.bundles.hm.web-fetchers =
{ pkgs, ... }:
let packageList = with pkgs; [
    curl
];
in
{
    home.packages = packageList;
}
;}
