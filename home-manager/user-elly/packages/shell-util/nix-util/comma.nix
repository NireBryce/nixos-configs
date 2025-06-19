{ ... }:
{
    # TODO: fix comma
    # description = "`,` - `nix-shell -p` style run commands without installing to env";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        comma
    ];
    in
    {
        home.packages = packageList;
    };
}
