# desc = "jq https://github.com/stedolan/jq";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        jq
    ];
}
