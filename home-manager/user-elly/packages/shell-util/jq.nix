{ ... }:
{
    description = "jq https://github.com/stedolan/jq";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        jq
    ];
    in
    {
        home.packages = packageList;
    };
}
