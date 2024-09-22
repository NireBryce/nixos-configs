{ 
  self,
  ... 
}:

let flakePath = self;

in let
    hm-nix-defaults     = "${flakePath}/home-manager/user-elly/_defaults-nix.nix";

    wm-kde          = "${flakePath}/home-manager/user-elly/window-manager/_kde.nix";
    pkgs-cli        = "${flakePath}/home-manager/user-elly/_pkgs-general-cli.nix";
    pkgs-linux-gui  = "${flakePath}/home-manager/user-elly/_pkgs-linux-gui.nix";
    pkgs-linux-cli  = "${flakePath}/home-manager/user-elly/_hm.elly.pkgs-linux-cli.nix";
    pkgs-dev        = "${flakePath}/home-manager/user-elly/_pkgs-dev.nix";
    dotfiles        = "${flakePath}/home-manager/user-elly/dotfiles/default.nix";
    shells          = "${flakePath}/home-manager/user-elly/_shells.nix";
    git             = "${flakePath}/home-manager/user-elly/_git.nix";
    shell-paths     = "${flakePath}/home-manager/user-elly/_shell-paths.nix";
    shell-aliases   = "${flakePath}/home-manager/user-elly/_shell-aliases.nix";

in {
    desciption =  "This defines the nire-durandal host-specific user config for elly";
    
    imports = [
      hm-nix-defaults
      wm-kde
      pkgs-cli
      pkgs-linux-gui
      pkgs-linux-cli
      pkgs-dev
      dotfiles
      shells
      shell-paths
      shell-aliases
      git
    ];

  ## Defaults
    nixpkgs.config = {
        allowUnfree          =     true;            # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
    home.username            = "elly";
    home.homeDirectory       = "/home/elly";

    home.stateVersion        = "22.11"; # Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
