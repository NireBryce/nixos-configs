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

  services.fwupd.enable = true;         # fwupd
  programs.nix-ld.enable = true;        # Needed for VSCode remote connection
  programs.kdeconnect.enable = true;    # kde connect
  programs.xwayland.enable = true;      # xwayland
  programs.nh = {                                   # `nh` nix-helper           https://github.com/viperML/nh
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/home/elly/nixos";
  };

  
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

    programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database

}
