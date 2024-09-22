{ 
	self,
	... 
}:
let 
  flakePath = self;
in let 
## imports
  #* user.elly
    dotfiles        = "${flakePath}/home-manager/user-elly/dotfiles/default.nix";
    pkgs-cli        = "${flakePath}/home-manager/user-elly/_pkgs-general-cli.nix";
    pkgs-darwin     = "${flakePath}/home-manager/user-elly/_pkgs-darwin.nix";            
    pkgs-dev        = "${flakePath}/home-manager/user-elly/_pkgs-dev.nix";
    git             = "${flakePath}/home-manager/user-elly/_git.nix";
    shells-bash     = "${flakePath}/home-manager/user-elly/_shells-bash.nix";
    shells-zsh      = "${flakePath}/home-manager/user-elly/_shells-zsh.nix";
    shell-aliases   = "${flakePath}/home-manager/user-elly/_shell-aliases.nix";
    shell-paths     = "${flakePath}/home-manager/user-elly/_shell-paths.nix";

in {
    imports = [
      git
      shells-bash
      shells-zsh
      pkgs-cli
      pkgs-darwin
      pkgs-dev
      dotfiles
      shell-aliases
      shell-paths
      shells-zsh
      shells-bash
      
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
