# desc = "nix-command zsh completions";
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-zsh-completions
];
in
{
    home.packages = packageList;
}
