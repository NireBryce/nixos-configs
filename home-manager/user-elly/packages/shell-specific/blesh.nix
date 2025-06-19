{ ... }:
{
    description = "bash line editor, allows zsh-like line editor tricks and bindings";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        blesh
    ];
    in
    {
        home.packages = packageList;
    };
}
