# desc = "nix-command zsh completions";
# I think this belongs here more than with the zsh completions elsewhere
{ flake.modules.homeManager.common.shells.zsh.completions.nix-completions =
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-zsh-completions
];
in
{
    home.packages = packageList;
}
;}
