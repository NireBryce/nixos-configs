{ pkgs, ...}:
{
  # console.font = "FiraCode";
  programs.zsh.enable = true;

  
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


