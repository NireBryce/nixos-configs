{ lib, pkgs, ...}:

{
  
  environment.pathsToLink = [   # Make sure system completions work even with home-manager managed shells 
    "/share/zsh"
    "/share/bash-completion"
    "/share/fish"
  ];

  ## shells
    environment.shells = with pkgs; [
        bash
        zsh
    ];
  ## zsh is handled through home-manager
    programs.zsh.enable = true;
    programs.zsh.enableCompletion = lib.mkForce false;    # unless disabled, home-manager causes an extra compaudit
  
  ## Bash Plugins
    environment.systemPackages = with pkgs; [
        inshellisense       # menu-complete and auto-suggest
        starship            # theming
        blesh               # if bash were zsh
    ];

    
}


