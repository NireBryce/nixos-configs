{
    # note: optional pkg
    description = "vlc media player";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            vlc
        ];
    };
}
