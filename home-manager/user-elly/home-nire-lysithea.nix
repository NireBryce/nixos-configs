{ 
	self,
	... 
}:
let 
    flakePath               = self; # the root of the flake
    ellyPath                = "${flakePath}/home-manager/user-elly";

    _dotfiles               = "${ellyPath}/dotfiles";
    _git                    = "${ellyPath}/git";
    _pkgs-cli               = "${ellyPath}/packages/_general-cli-pkgs.nix";
    _pkgs-darwin            = "${ellyPath}/packages/_darwin-pkgs.nix";            
    _pkgs-dev               = "${ellyPath}/packages/_dev-pkgs.nix";
    _shell                  = "${ellyPath}/shell";

in {
    imports = [
        _dotfiles           # dotfiles
        _git                # git
        _pkgs-cli           # general cli packages
        _pkgs-darwin        # mac-only packages
        _pkgs-dev           # dev packages (mostly nix)
        _shell              # zsh config, bash launch commands, paths, etc
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
