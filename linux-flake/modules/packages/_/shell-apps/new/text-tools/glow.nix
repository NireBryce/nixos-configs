{
    description = "terminal markdown viewer https://github.com/charmbracelet/glow";
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            glow
        ];
    };
}
