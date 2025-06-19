{ ... }:
{
    description = "curl https://curl.se/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        curl
    ];
    in
    {
        home.packages = packageList;
    };
}
