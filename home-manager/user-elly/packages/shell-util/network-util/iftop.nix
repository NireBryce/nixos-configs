{ ... }:
{
    description = "network monitor https://pdw.ex-parrot.com/iftop/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        iftop
    ];
    in
    {
        home.packages = packageList;
    };
}
