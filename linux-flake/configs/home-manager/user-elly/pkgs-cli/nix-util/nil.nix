# nil - a nix LSP server
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nil
];
in
{
    home.packages = packageList;
}
;}
