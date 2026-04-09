{
    description = "iotop - io monitoring http://guichaz.free.fr/iotop";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            iotop
        ];
    };
}
