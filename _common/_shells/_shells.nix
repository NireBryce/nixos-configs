{ pkgs, ...}:
{
  # programs._.enable = true;
  programs.zsh.enable = true;
  programs.bash.enable = true;
  
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
  };

users.users.elly.shell = pkgs.zsh;
}


/* non-system apps are handled through fleek, my config there is at nirebryce/fleek
 */
