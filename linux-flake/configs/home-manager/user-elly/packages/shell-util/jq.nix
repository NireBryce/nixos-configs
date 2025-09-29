# desc = "jq https://github.com/stedolan/jq";
{ pkgs, ... }:
let packageList = with pkgs; [
    jq
];
in
{
    home.packages = packageList;
}
