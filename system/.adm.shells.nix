{ lib, pkgs, ...}:

# Add mkEnableOption toggles
{
  # console.font = "FiraCode";
  programs.zsh.enable = true;
  programs.zsh.enableCompletion = lib.mkForce false; # Handled in home-manager, otherwise this calls compaudit
  programs.zsh.promptInit = lib.mkForce '''';
  

  
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

users.users.elly.shell = pkgs.zsh;
}


