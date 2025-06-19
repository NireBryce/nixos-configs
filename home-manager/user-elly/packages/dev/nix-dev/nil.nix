{ ... }:
{
    description = "nix LSP server";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nil
    ];
    in
    {
        home.packages = packageList;
    };
}
