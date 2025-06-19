{ ... }:
{
    description = "mask - markdown task runner";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        mask
    ];
    in
    {
        home.packages = packageList;
    };
}
