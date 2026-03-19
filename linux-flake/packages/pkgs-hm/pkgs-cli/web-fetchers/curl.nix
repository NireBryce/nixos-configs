# desc = "curl https://curl.se/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        curl
    ];
}
