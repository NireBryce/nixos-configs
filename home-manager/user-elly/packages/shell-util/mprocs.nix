{ ... }:
{
    description = "run multiple commands in parallel";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        mprocs
    ];
    in
    {
        home.packages = packageList;
    };
}
