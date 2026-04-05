{
    description = "per-character in-line diff";
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            riffdiff
        ];
    };
}
