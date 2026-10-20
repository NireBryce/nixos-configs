# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # an application to show file info
        home.packages = with pkgs; [
            file
        ];
    };
}
