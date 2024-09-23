{ 
  self,
  ... 
}:

let 
    flakePath = self;
    ellyPath = "${flakePath}/home-manager";
    _dotfiles       =       "${ellyPath}/dotfiles";
    _git            =       "${ellyPath}/git";
    _pkgs-cli       =       "${ellyPath}/packages/_general-cli-pkgs.nix";
    _pkgs-dev       =       "${ellyPath}/packages/_dev-pkgs.nix";
    _pkgs-linux-cli =       "${ellyPath}/packages/_linux-cli-pkgs.nix";
    _pkgs-linux-gui =       "${ellyPath}/packages/_linux-gui-pkgs.nix";
    _shell          =       "${ellyPath}/shell";
    _wm-kde         =       "${ellyPath}/window-manager/_kde.nix";

in {
    imports = [
        _dotfiles           # dotfiles
        _git                # elly git config
        _pkgs-cli           # general cli packages
        _pkgs-dev           # dev packages (mostly nix)
        _pkgs-linux-cli     # linux only cli tools
        _pkgs-linux-gui     # linux only gui tools
        _shell              # zsh config, bash launch commands, etc
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
