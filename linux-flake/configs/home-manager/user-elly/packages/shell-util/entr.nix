# desc = "run commands when file changes";
{ flake.modules.homeManager.packages.shellUtil.entr =
{ pkgs, ... }:
let packageList = with pkgs; [
    entr
];
in
{
    home.packages = packageList;
}
;}
