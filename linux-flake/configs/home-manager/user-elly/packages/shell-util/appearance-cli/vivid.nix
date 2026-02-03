# vivid - LS_COLORS generator
{ flake.modules.homeManager.shellUtil.appearance.vivid =
{ pkgs, ... }:
let packageList = with pkgs; [
    vivid
];
in
{
    home.packages = packageList;
}
;}
