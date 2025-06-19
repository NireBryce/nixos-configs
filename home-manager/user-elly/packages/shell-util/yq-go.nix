{ ... }:
{
    description = "yaml jq https://github.com/mikefarah/yq";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        yq-go
    ];
    in
    {
        home.packages = packageList;
    };
}
