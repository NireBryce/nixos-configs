{ pkgs, ...}:
{
  # List packages installed in system profile. To search, run:
  # $ nix search <package name>
  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    gcc
    git
    micro # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    stdenv
    wget
  ];
  # Needed for VSCode remote connection
  programs.nix-ld.enable = true;

  programs.kdeconnect.enable = true;

  services.fwupd.enable = true;


  # shells
  environment.shells = [
                          pkgs.bash
                       ];

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };
}


/* non-system apps are handled through fleek, my config there is at nirebryce/fleek
 */
