{ 
	self,
	... 
}:
let flakePath = self;

in {
  imports = [
    "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.general.nix"            # CLI packages
    "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.darwin.nix"            # CLI packages
    
    "${flakePath}/home-manager/meta/_hm.stateVersion.nix"
    "${flakePath}/home-manager/home.nix"
    "${flakePath}/home-manager/users/elly/_hm.elly.git.nix"

    
  ];

  home.username = "elly";
  home.homeDirectory = "/Users/elly";

}
