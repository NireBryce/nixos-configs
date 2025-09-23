# desc = "nix LSP server";
{ pkgs, ... }:
let packageList = with pkgs; [
    nil
];
in
{
    home.packages = packageList;
}
