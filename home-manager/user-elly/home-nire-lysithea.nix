{ 
	self,
	... 
}:
let 
  flakePath = self;
in let 
## imports
    _dotfiles               = "${flakePath}/home-manager/user-elly/dotfiles/default.nix";
    _git                    = "${flakePath}/home-manager/user-elly/_git.nix";
    _pkgs-cli               = "${flakePath}/home-manager/user-elly/_pkgs-general-cli.nix";
    _pkgs-darwin            = "${flakePath}/home-manager/user-elly/_pkgs-darwin.nix";            
    _pkgs-dev               = "${flakePath}/home-manager/user-elly/_pkgs-dev.nix";
    _shell-common           = "${flakePath}/home-manager/user-elly/_shell-common.nix";
    _shells                 = "${flakePath}/home-manager/user-elly/_shells.nix";

in {
    imports = [
        _dotfiles           # dotfiles
        _git                # elly git config
        _pkgs-cli           # general cli packages
        _pkgs-darwin        # mac-only packages
        _pkgs-dev           # dev packages (mostly nix)
        _shell-common       # shell aliases, paths, etc
        _shells             # zsh config, bash launch commands
    ];

    desciption = 
    "This defines the nire-lysithea host-specific user config for elly";

  ## Defaults
    nixpkgs.config = {
        allowUnfree          =     true;            # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
    home.username            = "elly";
    home.homeDirectory       = "/Users/elly";

    home.stateVersion        = "22.11"; # Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.
}
