{
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            fselect
        ];
    };
}
