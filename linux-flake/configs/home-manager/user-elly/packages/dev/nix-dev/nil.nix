# nil - a nix LSP server
{ flake.modules.homeManager.development.nix.nil =
{ pkgs, ... }:
let packageList = with pkgs; [
    nil
];
in
{
    home.packages = packageList;
}
;}
