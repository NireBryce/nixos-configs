{ ... }:
{
    description = "discord chat https://discord.com/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        discord
    ];
    in
    {
        home.packages = packageList;
    };
}
