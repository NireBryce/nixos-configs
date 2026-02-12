# desc = "jq https://github.com/stedolan/jq";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    jq
];
in
{
    home.packages = packageList;
}
;}
