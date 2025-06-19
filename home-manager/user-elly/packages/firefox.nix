{ ... }:
{
    description = "  ";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    {
        # todo: this is also installed as a system package, does that matter?
        home.packages = with pkgs; [ firefox ];
    };
}
