# desc = "yaml jq https://github.com/mikefarah/yq";
{ flake.modules.homeManager.packages.shellUtil.yq-go =
{ pkgs, ... }:
let packageList = with pkgs; [
    yq-go
];
in
{
    home.packages = packageList;
}
;}
