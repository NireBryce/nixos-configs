# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # nix package version diff
        home.packages = with pkgs; [
            nvd
        ];
    };
}
