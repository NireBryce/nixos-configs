{ 
	self,
	... 
}:
let 
  flakePath = self;
in let
  ## imports

  #* home-manager
    hm-state                    = "${flakePath}/home-manager/meta/_hm.stateVersion.nix";
    hm-nix-defaults             = "${flakePath}/home-manager/_hm.hm-nix-defaults.nix";  
  #* user.elly
    elly-cli-packages           = "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.general.nix";
    elly-darwin-packages        = "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.darwin.nix";            
    elly-development-packages   = "${flakePath}/home-manager/dev/default.nix";
    elly-dotfiles               = "${flakePath}/home-manager/dotfiles/default.nix";
    elly-git-hm                 = "${flakePath}/home-manager/users/elly/_hm.elly.git.nix";
    elly-shells                 = "${flakePath}/home-manager/_hm.shells.nix";
in {
    imports = [
      hm-state
      hm-nix-defaults
      elly-git-hm
      elly-shells
      elly-cli-packages
      elly-darwin-packages
      elly-development-packages
      elly-dotfiles
      

      # Previously on home.nix:
        

        
        "${flakePath}/home-manager/_hm.bash.nix"                # bash
    ];

  home.username = "elly";
  home.homeDirectory = "/Users/elly";

}
