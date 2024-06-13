{ 
	self,
  ... 
}:

let flakeRoot = self;
in {
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
    # TODO: we need to make this host-agnostic by splitting it or using options

		"${flakeRoot}/home-manager/meta/_hm.stateVersion.nix"
    "${flakeRoot}/home-manager/home.nix"

    "${flakeRoot}/home-manager/users/elly/_hm.elly.hm-meta.nix"
		"${flakeRoot}/home-manager/users/elly/_hm.elly.git.nix"
		"${flakeRoot}/home-manager/users/elly/_hm.elly.pkgs.general.nix"        # TODO: remove terminal emulator from this
	  "${flakeRoot}/home-manager/users/elly/_hm.elly.pkgs.gui.nix"

	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
