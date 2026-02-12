# nil - a nix LSP server
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nil
];
in
{
    home.packages = packageList;
}
;}
