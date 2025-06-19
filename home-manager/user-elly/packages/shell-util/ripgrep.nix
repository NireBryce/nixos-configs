{ ... }:
{
    description = "`rg` much faster grep alternative";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        ripgrep
    ];
    in
    {
        home.packages = packageList;
    };
}
