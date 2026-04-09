{
    description = "IP address calculator https://gitlab.com/ipcalc/ipcalc";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            ipcalc
        ];
    };
}
