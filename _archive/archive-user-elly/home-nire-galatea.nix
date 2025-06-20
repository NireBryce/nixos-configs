{ 
  self,
  ... 
}:
let flakePath = self;

in {
  # This defines the nire-durandal host-specific user config for elly
    imports = [
      
        # TODO: fix these, refer to durandal or lysithea
        "${flakePath}/home-manager/window-manager/_kde.nix"      								# window-manager specific packages

        "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.general.nix"      # CLI packages
        # "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.gui.nix" 				# GUI packages


        "${flakePath}/home-manager/users/elly/_hm.elly.hm-meta.nix"
        "${flakePath}/home-manager/users/elly/_hm.elly.git.nix"

        "${flakePath}/home-manager/_hm.hm-nix-defaults.nix"
        
      # previously on home.nix:
        "${flakePath}/home-manager/dev/default.nix"
        "${flakePath}/home-manager/dotfiles/default.nix"
        "${flakePath}/home-manager/_hm.shells.nix"              # shells
        "${flakePath}/home-manager/_hm.bash.nix"                # bash
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
