# yazi - file browser MAKE BETTER DESC
{ flake.modules.homeManager.shellUtil.fileBrowser.yazi =
{ pkgs, ... }:
let packageList = with pkgs; [
    yazi
];
in
{
    home.packages = packageList;
}
;}
