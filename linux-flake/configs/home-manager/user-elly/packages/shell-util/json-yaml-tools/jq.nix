# desc = "jq https://github.com/stedolan/jq";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    jq
];
in
{
    home.packages = packageList;
}
;}
