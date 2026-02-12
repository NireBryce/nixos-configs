# desc = "nix package version diff";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nvd
];
in
{
    home.packages = packageList;
}
;}
