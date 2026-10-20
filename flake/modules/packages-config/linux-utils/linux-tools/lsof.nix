# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # list open files https://linux.die.net/man/1/lsof
        home.packages = with pkgs; [
            lsof
        ];
    };
}
