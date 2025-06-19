{ ... }:
{
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            davinci-resolve
        ];
    in 
    {
        home.packages = packageList;
    };
}
