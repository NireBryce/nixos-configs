{ ... }:
{
    description = "Audacity audio editor";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            audacity
        ];
    in 
    {
        home.packages = packageList;
    };
}
