{
    nixpkgs,
    ...
}:

{
    # TODO: probably deprecated by the nix-index flake import
    nix.nixPath = [                                           # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
        "nixpkgs=${nixpkgs}"
        "/nix/var/nix/profiles/per-user/root/channels"
    ];
  
}
