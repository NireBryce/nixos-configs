{ pkgs, ...}:
{
  # programs._.enable = true;
  programs = [
    zsh
    bash
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
  };
}


/* non-system apps are handled through fleek, my config there is at nirebryce/fleek
 */
