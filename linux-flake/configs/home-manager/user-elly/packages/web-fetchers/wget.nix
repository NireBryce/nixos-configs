# desc = "its like curl but different https://www.gnu.org/software/wget/";
{ flake.modules.homeManager.packages.webFetchers.wget =
{ pkgs, ... }:
let packageList = with pkgs; [
    wget
];
in
{
    home.packages = packageList;
}
;}
