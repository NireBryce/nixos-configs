# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # home-manager instance of python3
        home.packages = with pkgs; [
            python3
        ];
    };
}
