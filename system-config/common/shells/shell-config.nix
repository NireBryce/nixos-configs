{
  pkgs,
  lib,
  ...
}:

{
    ## Shells
    environment.shells = with pkgs; [
        bash
        zsh
        fish
    ];
  #? This determines what to add to /run/current-system/sw, generally defined elsewhere
  environment.pathsToLink = [
    #? Make sure system completions work even with home-manager managed shells 
      "/share/zsh"
      "/share/bash-completion"
      "/share/fish"
  ];
  #? zsh is handled through home-manager
    programs.zsh.enable = true;
    programs.zsh.enableCompletion = lib.mkForce false;  # unless disabled, home-manager causes an extra compaudit
}
