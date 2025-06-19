{ ... }:
{
    # desc = "home-manager instance of python3";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        python3
    ];
    in
    {
        home.packages = packageList;
    };
}
