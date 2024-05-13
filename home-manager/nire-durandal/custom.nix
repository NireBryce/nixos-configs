{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: move these into flake?
    ../_dotfiles
    ../_specialized/_gaming
    ../_specialized/_wm/_kde.nix
    ../_specialized/_dev
    ../_specialized/_graphical
    ../_specialized/_sound

		# Enables middle mouse scrolling instead of paste in kde
		./_bugfixes/_kde-middle-mouse-scroll.nix
	];
	# TODO: these should be in their own module as `mkDefault true` too
	# TODO: Also consider merging things instead of having _common now that you can toggle 
  _gui.enable       = true;
	_kde.enable       = true;
	_sound.enable     = true;
	_zsh.enable       = true;
	_wayland.enable   = true;

	# TODO: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap


}
