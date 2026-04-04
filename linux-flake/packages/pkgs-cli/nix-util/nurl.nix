# desc = "make nix fetcher calls from repository URLs";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nurl
    ];
}
