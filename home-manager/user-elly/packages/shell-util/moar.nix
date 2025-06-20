# desc = "better pager for some things https://github.com/walles/moar";
{ pkgs, ... }:
let packageList = with pkgs; [
    moar
];
in
{
    home.packages = packageList;
}
