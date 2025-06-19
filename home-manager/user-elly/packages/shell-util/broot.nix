{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    { ... }:

    {
        programs.broot = {
            enable  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
        };

    };
}
