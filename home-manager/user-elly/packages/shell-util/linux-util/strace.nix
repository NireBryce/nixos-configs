{ ... }:
{
    description = "system call tracer https://linux.die.net/man/1/strace";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        strace
    ];
    in
    {
        home.packages = packageList;
    };
}
