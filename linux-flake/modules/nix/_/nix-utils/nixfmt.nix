{
    description = "nixfmt - .nix file formatter";
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nixfmt
            nixpkgs-fmt
        ];
    };
}
