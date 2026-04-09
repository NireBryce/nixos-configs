{
    description = "vlc media player";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            vlc
        ];
    };
}
