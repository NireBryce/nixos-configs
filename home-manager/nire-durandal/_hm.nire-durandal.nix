{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: move these into flake?
		./_installed-packages.nix
		../__def.common.nix
		# Enables middle mouse scrolling instead of paste in kde
		./_bugfixes/_kde-middle-mouse-scroll.nix
	];
	# TODO: these should be in their own module as `mkDefault true` too
	# TODO: Also consider merging things instead of having _common now that you can toggle 
  # _hm-gui.enable       = true;
	_hm-sound.enable     = true;
	_hm-zsh.enable       = true;
	_hm-zsh-abbr.enable = true;
	_hm-wayland.enable   = true;
	_hm-kde.enable       = true;	
	# _hm-gaming.enable    = true;
	# TODO: move option declarations into top-level config

	# TODO: uncomment the mkifs


	# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
	


}
