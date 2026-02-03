# desc = "show filetype";
{ flake.modules.homeManager.packages.shellUtil.file =
{ pkgs, ... }:
let packageList = with pkgs; [
    file
];
in
{
    home.packages = packageList;
}
;}
