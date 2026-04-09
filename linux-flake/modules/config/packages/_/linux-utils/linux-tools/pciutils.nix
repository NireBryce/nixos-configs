{
    description = "`lspci`";

    homeManager = { pkgs, ... }: {

        home.packages = with pkgs; [
            pciutils
        ];
    };
}
