# desc = "file browser"; # TODO: better desc
{ pkgs, ... }:
let packageList = with pkgs; [
    yazi
];
in
{
    home.packages = packageList;
}
