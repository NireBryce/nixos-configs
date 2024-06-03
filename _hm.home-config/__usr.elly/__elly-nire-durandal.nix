{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: move these into flake?
		../hm-stateVersion.nix
		
		../__hm-default.nix

		# user
    ./_hm.elly.hm.nix
		./_hm.elly.git.nix
		./_hm.elly.pkgs.general.nix
		./_hm.elly.pkgs.gui.nix

		# machine
		../_hm.bugfixes/_kde-middle-mouse-scroll.nix        # Enables middle mouse scrolling instead of paste in kde	
	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
