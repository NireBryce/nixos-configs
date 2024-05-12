{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: clean this up later
    ../_dotfiles
    ../_specialized/_gaming
    ../_specialized/_wm/_kde.nix
    ../_specialized/_dev
    ../_specialized/_graphical
    ../_specialized/_sound

		# Enables middle mouse scrolling instead of paste in kde
		./_bugfixes/_kde-middle-mouse-scroll.nix
	];
}
