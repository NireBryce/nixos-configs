{ ... }:
{
    # desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        glow
    ];
    in
    {
        home.packages = packageList;
    };
}
