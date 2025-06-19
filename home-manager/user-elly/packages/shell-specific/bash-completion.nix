{ ... }:
{
    # desc = "bash completions";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        bash-completion
    ];
    in
    {
        home.packages = packageList;
    };
}
