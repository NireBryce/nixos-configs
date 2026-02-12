# desc = "`rg` much faster grep alternative";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ripgrep
];
in
{
    home.packages = packageList;
}
;}
