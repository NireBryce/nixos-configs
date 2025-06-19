{ ... }:
{
    # desc = "nix formatter";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nixfmt
    ];
    in
    {
        home.packages = packageList;
    };
}
