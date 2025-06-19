{ ... }:
{
    # desc = "bash formatter";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        shfmt
    ];
    in
    {
        home.packages = packageList;
    };
}
