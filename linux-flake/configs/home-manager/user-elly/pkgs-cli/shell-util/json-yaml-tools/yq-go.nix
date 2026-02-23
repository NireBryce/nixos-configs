# desc = "yaml jq https://github.com/mikefarah/yq";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    yq-go
];
in
{
    home.packages = packageList;
}
;}
