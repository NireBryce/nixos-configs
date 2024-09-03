{ lib, pkgs, ...}:

{
  programs.zsh.enable = true;
  programs.zsh.enableCompletion = lib.mkForce false;    # Handled in home-manager, otherwise this calls compaudit
  
  environment.pathsToLink = [   # Make sure system completions work even with home-manager managed shells 
    "/share/zsh"
    "/share/bash-completion"
    "/share/fish"
    ];

  # shells
  environment = {
    shells = with pkgs; [
      bash
      zsh
    ];
  };


}


