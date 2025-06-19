{ ... }:
{
    description = "magic-wormhole point to point file transfer";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        magic-wormhole-rs
    ];
    in
    {
        home.packages = packageList;
    };
}
