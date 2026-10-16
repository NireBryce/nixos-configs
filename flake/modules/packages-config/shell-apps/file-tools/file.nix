# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # an application to show file info
        home.packages = with pkgs; [
            file
        ];
    };
}
