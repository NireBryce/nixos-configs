{
    ...
}:

{
    nix.extraOptions    = "experimental-features = nix-command flakes";
    nix.settings        = {
        trusted-users          = [ "root" ];
        experimental-features  = [ 
            "nix-command"
            "flakes" 
        ];
    };
    
    nixpkgs.config.allowUnfree = true;
    
    # TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots
}
