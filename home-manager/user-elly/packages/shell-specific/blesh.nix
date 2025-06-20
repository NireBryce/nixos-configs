# desc = "bash line editor, allows zsh-like line editor tricks and bindings";
{ pkgs, ... }:
let packageList = with pkgs; [
    blesh
];
in
{
    home.packages = packageList;
}
