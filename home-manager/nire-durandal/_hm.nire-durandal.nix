{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: move these into flake?
		./_installed-packages.nix
		./hm-stateVersion.nix
		
		../home.nix
		../__def.common.nix

		# user
		./_usr.elly.nix

		./_bugfixes/_kde-middle-mouse-scroll.nix        # Enables middle mouse scrolling instead of paste in kde	
	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
