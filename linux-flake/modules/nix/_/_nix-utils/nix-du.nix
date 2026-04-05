{
    description = "nix-store analysis"; 
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nix-du
        ];
    };
}
