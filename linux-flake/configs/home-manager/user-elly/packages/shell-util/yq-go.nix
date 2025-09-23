# desc = "yaml jq https://github.com/mikefarah/yq";
{ pkgs, ... }:
let packageList = with pkgs; [
    yq-go
];
in
{
    home.packages = packageList;
}
