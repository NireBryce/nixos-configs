{ ... }:
{
    # desc = "library call tracer https://linux.die.net/man/1/ltrace";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        ltrace
    ];
    in
    {
        home.packages = packageList;
    };
}
