{ 
	self,
  ... 
}:

let flakePath = self;
in {
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
    # TODO: we need to make this host-agnostic by splitting it or using options

		"${flakePath}/home-manager/meta/_hm.stateVersion.nix"
    "${flakePath}/home-manager/home.nix"

    "${flakePath}/home-manager/users/elly/_hm.elly.hm-meta.nix"
		"${flakePath}/home-manager/users/elly/_hm.elly.git.nix"
		"${flakePath}/home-manager/users/elly/_hm.elly.pkgs.general.nix"        # TODO: remove terminal emulator from this
	  "${flakePath}/home-manager/users/elly/_hm.elly.pkgs.gui.nix"

	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
