{ ... }:
{
    # desc = "input-level keybinding, platform independent";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        kanata
    ];
    in
    {
        home.packages = packageList;
    };
}
