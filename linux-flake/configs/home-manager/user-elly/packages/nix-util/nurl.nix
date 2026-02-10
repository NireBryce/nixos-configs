# desc = "make nix fetcher calls from repository URLs";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nurl
];
in
{
    home.packages = packageList;
}
;}
