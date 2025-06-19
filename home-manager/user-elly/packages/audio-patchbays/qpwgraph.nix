{ ... }:
{
    description = "qpw graph virtual mixer";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            qpwgraph
        ];
    in 
    {
        home.packages = packageList;
    };
}
