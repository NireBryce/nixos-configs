{
    description = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            bat
        ];
    };
}
