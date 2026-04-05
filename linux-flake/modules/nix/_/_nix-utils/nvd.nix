{
    description = "nix package version diff";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nvd
        ];
    };
}
