{ ... }:
{
    # desc = "tldr - community provided man pages";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        tldr
    ];
    in
    {
        home.packages = packageList;
    };
}
