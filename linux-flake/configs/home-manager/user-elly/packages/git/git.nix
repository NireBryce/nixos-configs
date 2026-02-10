# git - git-scm
{ den.bundles.hm.git =
{ pkgs, ... }:
let packageList = with pkgs; [
    git
];
in
{
    home.packages = packageList;
}
;}
