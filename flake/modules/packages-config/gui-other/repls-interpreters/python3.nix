# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # home-manager instance of python3
        home.packages = with pkgs; [
            python3
        ];
    };
}
