{ ... }:
{
    description = "Bitwarden password manager https://bitwarden.com/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        bitwarden
    ];
    in
    {
        home.packages = packageList;
    };
}
