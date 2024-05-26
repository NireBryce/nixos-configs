{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: move these into flake?
		../../0U0-general/hm-stateVersion.nix
		
		../100-home-manager/__def.common.nix

		# user
    ./_hm.elly.hm.nix
		./_hm.elly.git.nix

		# machine
		./_hm.elly.pkgs.nix
		./_hm.elly.pkgs-gui.nix
		../100-home-manager/_bugfixes/_kde-middle-mouse-scroll.nix        # Enables middle mouse scrolling instead of paste in kde	
	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
