{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    { ... }:

    {
        programs.dircolors = {
            enable = true;
            enableZshIntegration = true;
            enableBashIntegration = true;
            enableFishIntegration = true;
        };
    };
}
