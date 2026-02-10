# desc = "nix-command zsh completions";
# I think this belongs here more than with the zsh completions elsewhere
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-zsh-completions
];
in
{
    home.packages = packageList;
}
;}
