# gh - github-cli
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    gh
];
in
{
    home.packages = packageList;
}
;}
