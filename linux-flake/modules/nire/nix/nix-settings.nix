{ self, inputs, ...}:
{ flake.nixosModules.nix= { 
    nix.extraOptions    = "experimental-features = nix-command flakes";
    nix.settings        = {
        trusted-users          = [ "root" ];
        experimental-features  = [
            # duplicated in extraOptions?
            "nix-command" 
            "flakes" 
        ];
    };

    # FIX: `comma` fix https://github.com/nix-community/comma/issues/43 (25.12.01)
    nix.channel.enable = false; 

    nixpkgs.config.allowUnfree = true;
    
    # NOTE: make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
    # WISHLIST: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots
};

}

