# desc = "yaml jq https://github.com/mikefarah/yq";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    yq-go
];
in
{
    home.packages = packageList;
}
;}
