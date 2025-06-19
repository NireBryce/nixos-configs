{ ... }:
{
    # desc = "nix man pages, kinda";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        manix
    ];
    in
    {
        home.packages = packageList;
    };
}
