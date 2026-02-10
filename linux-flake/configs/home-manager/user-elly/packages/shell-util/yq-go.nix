# desc = "yaml jq https://github.com/mikefarah/yq";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    yq-go
];
in
{
    home.packages = packageList;
}
;}
