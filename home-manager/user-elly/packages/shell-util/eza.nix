{ ... }:
{
    # desc = "";
    flake.modules.homeManager.base =
    { ... }:

    {
        programs.eza = {
            enable  = true;
            enableZshIntegration    = true;
            enableBashIntegration   = true;
        };
    };
}
