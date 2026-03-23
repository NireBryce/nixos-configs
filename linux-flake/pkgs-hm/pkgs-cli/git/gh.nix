# gh - github-cli
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        gh
    ];
}
