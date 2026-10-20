# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # description = "zoom videoconferencing software";
        home.packages = with pkgs; [
            zoom-us
        ];
    };
}
