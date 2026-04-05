{
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            sqlite
        ];
    };
}
