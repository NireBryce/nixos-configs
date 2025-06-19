{ ... }:
{
    description = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        ipcalc
    ];
    in
    {
        home.packages = packageList;
    };
}
