{ 
  pkgs, 
  lib,
  self, 
  ...
}:

# system packages metapackage
# TODO: trawl through home-manager config fragments and see what packages really need to be system packages

let flakePath = self;
in {
  imports = [ 
    "${flakePath}/___modules/linux-crisis-utilities.nix"
  ];

    environment.systemPackages = with pkgs; [ # Always have an editor here
      bash                                          # bash.  ok i guess.
      coreutils                                     # coreutils
      curl                                          # curl
      gcc                                           # gcc
      git                                           # git
      micro                                         # micro
      stdenv                                        # stdenv
      wget                                          # wget
      zoxide                                        # zoxide
      ripgrep                                       # ripgrep
      nix-output-monitor                            # `nom` nix-output-monitor  https://github.com/maralorn/nix-output-monitor
      nh                                            # nix helper                https://github.com/viperML/nh
      linuxHeaders                                  # linux headers
      sops                                          # secret management
    ];

  programs.nh = {                                   # `nh` nix-helper           https://github.com/viperML/nh
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 7d --keep 5";
      flake = "/Users/elly/nixos";
    };

    # programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database

  # TODO: fixme for darwin
    # fonts.packages = with pkgs; [
    #   (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" ];})  # be not afraid
    # ];
}
