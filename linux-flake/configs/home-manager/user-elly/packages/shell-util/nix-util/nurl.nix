# desc = "make nix fetcher calls from repository URLs";
{ pkgs, ... }:
let packageList = with pkgs; [
    nurl
];
in
{
    home.packages = packageList;
}
