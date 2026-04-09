{
    description = "diff nix code";
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nix-diff
        ];
    };
}
