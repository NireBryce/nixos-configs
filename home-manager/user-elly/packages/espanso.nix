{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    { ... }:

    {
        services.espanso = {
            enable  = true;
            waylandSupport = true;
        };
    };
}
