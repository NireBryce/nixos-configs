# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # bitwarden - password manager https://bitwarden.com/
        home.packages = with pkgs; [
            bitwarden-desktop
        ];
    };
}
