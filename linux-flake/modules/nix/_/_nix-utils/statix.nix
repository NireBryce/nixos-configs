{
    description = "nix antipattern linter";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            statix
        ];
    };
}
