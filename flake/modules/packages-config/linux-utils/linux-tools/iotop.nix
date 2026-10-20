# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # iotop - io monitoring http://guichaz.free.fr/iotop
        home.packages = with pkgs; [
            iotop
        ];
    };
}
