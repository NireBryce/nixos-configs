# desc = "show filetype";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    file
];
in
{
    home.packages = packageList;
}
;}
