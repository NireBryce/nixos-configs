#* This defines the nire-lysithea host-specific user config for elly


# ! NOTE !
# ? Packages are currently managed via darwin.
{ 
	... 
}:
let 
    flakePath               = ../..; # the root of the flake
    ellyPath                = "${flakePath}/home-manager/user-elly";

    _dotfiles               = "${ellyPath}/dotfiles";
    _git                    = "${ellyPath}/git";
  # TODO: make these names less confusing even though they're to optimize for code-skim and file-manager sort respectively
    # _pkgs-cli               = "${ellyPath}/packages/_general-cli-pkgs.nix";
    # _pkgs-darwin            = "${ellyPath}/packages/_darwin-pkgs.nix";            
    # _pkgs-dev               = "${ellyPath}/packages/_dev-pkgs.nix";
    # _shell                  = "${ellyPath}/shell";

in {
    imports = [
        _dotfiles           # dotfiles
        _git                # git
        ./packages/cli-pkgs/shell
        # _pkgs-cli           # general cli packages
        # _pkgs-darwin        # mac-only packages
        # _pkgs-dev           # dev packages (mostly nix)
        # _shell              # zsh config, bash launch commands, paths, etc
    ];

    
  ## Defaults
    nixpkgs.config = {
        allowUnfree          =     true;            # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
    home.username            = "elly";
    home.homeDirectory       = "/Users/elly";
    
    #! Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.
    home.stateVersion        = "22.11"; 
}
