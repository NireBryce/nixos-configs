# desc = "jq https://github.com/stedolan/jq";
{ flake.modules.homeManager.packages.shellUtil.jq =
{ pkgs, ... }:
let packageList = with pkgs; [
    jq
];
in
{
    home.packages = packageList;
}
;}
