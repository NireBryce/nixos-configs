{ ... }:
{
    description = "";
    flake.modules.homeManager.base =
    { ... }:

    {
        programs.tmux = {
            enable = true;
        };
    };
}
