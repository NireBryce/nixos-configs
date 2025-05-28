{ pkgs, ...}:
# This is where the home-manager package list lives.  Do not consider this complete,
# as some packages are installed in their modules.
{

# TODO: make server config


  home.packages = with pkgs; [    # TODO: figure out which should be modularized for, say, headless machines

    ## Keybinds
      
      # TOOD: broken


    # system interpreters (everything else should be virtualenv or dev shell)
      python3                       # system python, zsh complains without      https://python.org
  
    # cli tools                 # cli tools                                 # CLI tools
      # todo: fix topgrade to ignore what it cannot change and mostly stick to git repos
      # todo: fix for darwin-nix too

    # editors                   # editors                                   # editors
      

    # file transfer             # file transfer                             # file transfer

                                 
  ];  
  # programs are packages you set extra pre-defined options in.
  #   google 'home-manager option search' to see how to find them.





  
  }


  # GPU diagnostic packages live in ../000-nire-durandal-host/_gpu.nix
  # GUI-primary packages live in ./elly.gui-pkgs.nix

  # Things to look into:
    # MyNixOS
    # nixpkgs-wayland
    # nix-direnv
    # haumea                # nix configuration tool that allows you to just use the filesystem instead of imports 
    # flakelight            # less flake boilerplate
    # flake-utils
    # flake-utils-plus
    # flake-parts           # module system for flakes
    # devshell              # like virtualenv
    # devbox                # isolated development shells, maybe like the above
    # devenv                # same
    # nixos-shell           # easy VMs
    # nix-index             # quickly locate packages providing a certain file
    # nix-prefetch          # determine hash of fixed-output derivations such as package source
