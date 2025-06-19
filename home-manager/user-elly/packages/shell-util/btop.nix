{ ... }:
{
    description = "`htop` alternative";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        btop
    ];
    in
    {
        home.packages = packageList;
    };
}
