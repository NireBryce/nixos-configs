{
    nixpkgs,
    ...
}:

{
    nix.extraOptions    ="experimental-features = nix-command flakes";
    nix.settings        = {
        trusted-users          = [ "root" ];
        experimental-features  = [
            # duplicated in extraOptions?
            "nix-command" 
            "flakes" 
        ];
    };

    # `comma` fix https://github.com/nix-community/comma/issues/43 (25.12.01)
        nix.channel.enable = false; 
        # nixpkgs.flake.setNixPath = true;
        # nixpkgs.flake.setFlakeRegistry = true;  
        # nix.nixPath = [ "nixpkgs=${nixpkgs.outPath}" ];

    nixpkgs.config.allowUnfree = true;
    
    # TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots
}

# warning: /root/.nix-defexpr/channels exists, but channels have been disabled.
# warning: /nix/var/nix/profiles/per-user/root/channels exists, but channels have been disabled.
# warning: /root/.nix-defexpr/channels exists, but channels have been disabled.
# warning: /home/elly/.nix-defexpr/channels exists, but channels have been disabled.
# Due to https://github.com/NixOS/nix/issues/9574, Nix may still use these channels when NIX_PATH is unset.
# Delete the above directory or directories to prevent this.


