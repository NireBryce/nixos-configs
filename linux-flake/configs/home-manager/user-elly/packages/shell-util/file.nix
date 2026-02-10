# desc = "show filetype";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    file
];
in
{
    home.packages = packageList;
}
;}
