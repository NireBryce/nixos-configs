{ ... }:
{
    # desc = "";
    flake.modules.homeManager.base =
    { ... }:

    {
        programs.starship = {
            enable = true;
            enableBashIntegration = true;
            enableZshIntegration = true;
            enableFishIntegration = true;
        };
    };
}
