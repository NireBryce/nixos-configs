{ pkgs, misc, ... }: {
  home.packages = [
    pkgs.steamtinkerlaunch
    pkgs.r2modman
  ];

# Steam itself is set up through nixos configuration 
# https://nixos.wiki/wiki/Steam

}

