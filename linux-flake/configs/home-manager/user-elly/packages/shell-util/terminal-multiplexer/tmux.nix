# desc = "";
{ flake.modules.homeManager.packages.shellUtil.multiplexer.tmux =
    { ... }:

{
    programs.tmux = {
        enable = true;
    };
}
;}
