{ ... }:
{
    # desc = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        bat
    ];
    in
    {
        home.packages = packageList;
    };
}
