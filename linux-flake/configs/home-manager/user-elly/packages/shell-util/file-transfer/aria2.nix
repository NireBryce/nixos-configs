# aria2 -cli download manager
{ flake.modules.homeManager.shellUtil.fileTransfer.aria2 =
{ pkgs, ... }:
let packageList = with pkgs; [
    aria2
];
in
{
    home.packages = packageList;
}
;}
