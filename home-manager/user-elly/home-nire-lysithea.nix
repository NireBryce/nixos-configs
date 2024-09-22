{ 
	self,
	... 
}:
let 
  flakePath = self;
in let 
## imports
  #* user.elly
    _dotfiles        = "${flakePath}/home-manager/user-elly/dotfiles/default.nix";
    _pkgs-cli        = "${flakePath}/home-manager/user-elly/_pkgs-general-cli.nix";
    _pkgs-darwin     = "${flakePath}/home-manager/user-elly/_pkgs-darwin.nix";            
    _pkgs-dev        = "${flakePath}/home-manager/user-elly/_pkgs-dev.nix";
    _git             = "${flakePath}/home-manager/user-elly/_git.nix";
    _shells          = "${flakePath}/home-manager/user-elly/_shells.nix";
    _shell-defaults  = "${flakePath}/home-manager/user-elly/_shell-aliases.nix";

in {
    imports = [
        _git
        _shells
        _pkgs-cli
        _pkgs-darwin
        _pkgs-dev
        _dotfiles
        _shell-defaults
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
