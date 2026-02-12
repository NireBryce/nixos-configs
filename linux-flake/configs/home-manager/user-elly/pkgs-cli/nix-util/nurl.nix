# desc = "make nix fetcher calls from repository URLs";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nurl
];
in
{
    home.packages = packageList;
}
;}
