# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # iotop - io monitoring http://guichaz.free.fr/iotop
        home.packages = with pkgs; [
            iotop
        ];
    };
}
