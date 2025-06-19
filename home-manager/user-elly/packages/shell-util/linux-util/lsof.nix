{ ... }:
{
    # desc = "list open files https://linux.die.net/man/1/lsof";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        lsof
    ];
    in
    {
        home.packages = packageList;
    };
}
