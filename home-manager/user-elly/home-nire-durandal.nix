{ 
  self,
  ... 
}:

let flakePath = self;

in let
    _dotfiles               = "${flakePath}/home-manager/user-elly/dotfiles/default.nix";
    _git                    = "${flakePath}/home-manager/user-elly/_git.nix";
    _pkgs-cli               = "${flakePath}/home-manager/user-elly/_pkgs-general-cli.nix";
    _pkgs-dev               = "${flakePath}/home-manager/user-elly/_pkgs-dev.nix";
    _pkgs-linux-cli         = "${flakePath}/home-manager/user-elly/_hm.elly.pkgs-linux-cli.nix";
    _pkgs-linux-gui         = "${flakePath}/home-manager/user-elly/_pkgs-linux-gui.nix";
    _shell-common           = "${flakePath}/home-manager/user-elly/_shell-common.nix";
    _shells                 = "${flakePath}/home-manager/user-elly/_shells.nix";
    _wm-kde                 = "${flakePath}/home-manager/user-elly/window-manager/_kde.nix";

in {
    imports = [
        _dotfiles           # dotfiles
        _git                # elly git config
        _pkgs-cli           # general cli packages
        _pkgs-dev           # dev packages (mostly nix)
        _pkgs-linux-cli     # linux only cli tools
        _pkgs-linux-gui     # linux only gui tools
        _shell-common       # shell aliases, paths, etc
        _shells             # zsh config, bash launch commands
        _wm-kde             # kde config
    ];

    desciption = 
    "This defines the nire-durandal host-specific user config for elly";
    
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
