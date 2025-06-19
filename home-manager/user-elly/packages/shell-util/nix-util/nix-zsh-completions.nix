{ ... }:
{
    description = "nix-command zsh completions";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-zsh-completions
    ];
    in
    {
        home.packages = packageList;
    };
}
