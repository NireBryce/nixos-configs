{ ... }:
{
	# FEEL FREE TO EDIT: This file is NOT managed by fleek.
	imports = [
		# We split off configs that we might have to remove from specific machines
		# TODO: move these into flake?
    ../_dotfiles
		../_cfg.fzf.nix
		../_cfg.home-manager.nix
		../_cfg.micro.nix
		../_pkg.cli.nix
		../_pkg.gui+.nix
		../_pkg.wayland+.nix
		../_snd.sound+.nix
		../_sys.paths.nix
		../_sys.session-variables.nix
		../_usr.elly.nix
		../_wm.kde+.nix
		../_zsh.abbrs+.nix
		../_zsh.aliases.nix
		../_zsh.zsh+.nix
    ../_pkg.gaming+.nix
		
		

    ../_dev

		# Enables middle mouse scrolling instead of paste in kde
		./_bugfixes/_kde-middle-mouse-scroll.nix
	];
	# TODO: these should be in their own module as `mkDefault true` too
	# TODO: Also consider merging things instead of having _common now that you can toggle 
  _hm-gui.enable       = true;
	_hm-sound.enable     = true;
	_hm-zsh.enable       = true;
	_hm-zsh-abbr.enable = true;
	_hm-wayland.enable   = true;
	_hm-kde.enable       = true;	
	_hm-gaming.enable    = true;


	# TODO: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap


}
