# desc = "gnu which"; # TODO: better desc
{ pkgs, ... }:
let packageList = with pkgs; [
    which
];
in
{
    home.packages = packageList;
}
