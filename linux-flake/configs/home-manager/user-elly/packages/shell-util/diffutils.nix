# desc = "`diff` utils";
{ flake.modules.homeManager.packages.shellUtil.diffutils =
{ pkgs, ... }:
let packageList = with pkgs; [
    diffutils
];
in
{
    home.packages = packageList;
}
;}
