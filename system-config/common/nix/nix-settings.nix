{
    inputs,
    ...
}:

{
    nix.extraOptions    = "experimental-features = nix-command flakes"; # TODO: is this necessary, duplicated below?
    nix.settings        = {
        trusted-users          = [ "root" ];
        experimental-features  = [ 
            "nix-command"
            "flakes" 
        ];
    };
    
    nix.nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
    ];

    nixpkgs.config.allowUnfree = true;
    
    # TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots
}
