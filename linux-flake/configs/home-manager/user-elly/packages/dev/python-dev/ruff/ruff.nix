# ruff - python linter
{ den.bundles.hm.dev-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    ruff
];
in
{
    home.packages = packageList;
}
;}
