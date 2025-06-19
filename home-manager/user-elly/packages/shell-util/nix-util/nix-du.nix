{ ... }:
{
    # desc = "nix-store analysis";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-du
    ];
    in
    {
        home.packages = packageList;
    };
}
