{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nix-zsh-completions ];

    flake.modules.homeManager.nix-zsh-completions =
# desc = "nix-command zsh completions";
# I think this belongs here more than with the zsh completions elsewhere
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-zsh-completions
    ];
}
;}
