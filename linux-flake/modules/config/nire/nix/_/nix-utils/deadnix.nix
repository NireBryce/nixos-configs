{
     description = "scan for 'dead' (uncalled) nix code";
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            deadnix
        ];
    };
}
