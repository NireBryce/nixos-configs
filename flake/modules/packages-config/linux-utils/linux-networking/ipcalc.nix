# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # IP address calculator https://gitlab.com/ipcalc/ipcalc
        home.packages = with pkgs; [
            ipcalc
        ];
    };
}
