{ ... }:
{
    # desc = "python version- and venv-manager ";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        uv
    ];
    in
    {
        home.packages = packageList;
    };
}
