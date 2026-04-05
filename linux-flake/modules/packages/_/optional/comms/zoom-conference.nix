{
    description = "zoom videoconferencing software";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            zoom-us
        ];
    };
}
