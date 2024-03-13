{ pkgs, ...}:
{
  # console.font = "FiraCode";
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
    console.font = "FiraCode Nerd Font Mono";
  };

users.users.elly.shell = pkgs.zsh;
}


/* non-system apps are handled through fleek, my config there is at nirebryce/fleek
 */
