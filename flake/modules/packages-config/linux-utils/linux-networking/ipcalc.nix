# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # IP address calculator https://gitlab.com/ipcalc/ipcalc
        home.packages = with pkgs; [
            ipcalc
        ];
    };
}
