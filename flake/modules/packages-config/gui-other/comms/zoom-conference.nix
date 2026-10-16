# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # description = "zoom videoconferencing software";
        home.packages = with pkgs; [
            zoom-us
        ];
    };
}
