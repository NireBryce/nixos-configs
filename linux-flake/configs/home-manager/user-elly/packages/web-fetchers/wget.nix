# desc = "its like curl but different https://www.gnu.org/software/wget/";
{ den.bundles.hm.web-fetchers =
{ pkgs, ... }:
let packageList = with pkgs; [
    wget
];
in
{
    home.packages = packageList;
}
;}
