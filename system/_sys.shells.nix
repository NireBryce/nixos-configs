{ lib, pkgs, ...}:

{
  programs.zsh.enable = true;
  programs.zsh.enableCompletion = lib.mkForce false;    # Handled in home-manager, otherwise this calls compaudit
  programs.zsh.shellInit = lib.mkForce ''
    for profile in ''${(z)NIX_PROFILES}; do
      fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
    done'';
  
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

  console = {
    keyMap = "us";
    # useXkbConfig = true; # use xkb.options in tty.
    font = "Lat2-Terminus16";
  };


}


