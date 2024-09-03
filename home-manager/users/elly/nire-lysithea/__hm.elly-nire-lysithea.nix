{ 
	self,
	... 
}:
let flakePath = self;

in {
  imports = [
    "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.general.nix"            # CLI packages

    "${flakePath}/home-manager/users/elly/_hm.elly.git.nix"

    
  ];

}
