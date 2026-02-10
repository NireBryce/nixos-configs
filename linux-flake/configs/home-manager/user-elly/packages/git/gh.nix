# gh - github-cli
{ den.bundles.hm.git =
{ pkgs, ... }:
let packageList = with pkgs; [
    gh
];
in
{
    home.packages = packageList;
}
;}
