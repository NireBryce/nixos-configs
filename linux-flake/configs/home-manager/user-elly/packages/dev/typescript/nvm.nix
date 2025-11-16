# desc = "node version-manager ";
{ pkgs, ... }:
let packageList = with pkgs; [
    nvm
];
in
{   
    home.packages = packageList;
}
