{ 
	self,
	... 
}:
let flakePath = self;

in {
	# This defines the nire-durandal host-specific user config for elly
	imports = [
		
		    # TODO: we need to make this host-agnostic by splitting it or using options
		"${flakePath}/home-manager/window-manager/_kde.nix"      								# window-manager specific packages

		"${flakePath}/home-manager/users/elly/_hm.elly.pkgs.general.nix"        # CLI packages
		"${flakePath}/home-manager/users/elly/_hm.elly.pkgs.gui.nix" 						# GUI packages
		"${flakePath}/home-manager/users/elly/_hm.elly.linux.pkgs.cli.nix" 			# linux-only packages


    "${flakePath}/home-manager/users/elly/_hm.elly.hm-meta.nix"
		"${flakePath}/home-manager/users/elly/_hm.elly.git.nix"

		"${flakePath}/home-manager/meta/_hm.stateVersion.nix"
    "${flakePath}/home-manager/home.nix"
	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
