{ ... }:
{
    # desc = "neovim editor";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        neovim
    ];
    in
    {
        home.packages = packageList;
    };
}
