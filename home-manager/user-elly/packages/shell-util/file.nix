# desc = "show filetype";
{ pkgs, ... }:
let packageList = with pkgs; [
    file
];
in
{
    home.packages = packageList;
}
