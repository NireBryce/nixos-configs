# desc = "nix-command zsh completions";
# I think this belongs here more than with the zsh completions elsewhere
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-zsh-completions
];
in
{
    home.packages = packageList;
}
;}
