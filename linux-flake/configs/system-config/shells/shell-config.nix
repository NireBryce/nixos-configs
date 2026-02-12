{
    ...
}:
{ den.aspects.nixos.provides.shells = 
{ pkgs, lib, ... }: 
{
    # Shells
    environment.shells = with pkgs; [
        bash
        zsh
        fish
    ];
    # This determines what to add to /run/current-system/sw, generally defined elsewhere
    #   ensures system completions work even with home-manager managed shells 
    environment.pathsToLink = [
        "/share/zsh"
        "/share/bash-completion"
        "/share/fish"
    ];
    # zsh is handled through home-manager
    programs.zsh.enable = true;
    programs.zsh.enableCompletion = lib.mkForce false;  # unless disabled, home-manager causes an extra compaudit

    programs.fish.enable = true;
    environment.systemPackages = with pkgs; [
        fishPlugins.fzf-fish
    ];
    programs.bash.blesh.enable = true;
}
;}
