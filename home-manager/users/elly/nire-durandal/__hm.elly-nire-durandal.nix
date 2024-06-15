{ 
	self,
	... 
}:
let flakePath = self;

in {
	# This defines the nire-durandal host-specific user config for elly
	imports = [
		
		    # TODO: we need to make this host-agnostic by splitting it or using options
		# TODO: move to kde
		"${flakePath}/home-manager/bugfixes/_kde-middle-mouse-scroll.nix"        # Enables middle mouse scrolling instead of paste in kde	
	];
}

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
