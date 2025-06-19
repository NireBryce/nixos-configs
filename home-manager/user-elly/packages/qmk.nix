{ ... }:
{
    description = " qmk keyboard manager https://github.com/qmk/qmk_firmware";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            qmk
        ];
    in 
    {
        home.packages = packageList;
    };
}
