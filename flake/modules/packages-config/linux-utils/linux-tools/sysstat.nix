# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # system stats http://sebastien.godard.pagesperso-orange.fr/
        home.packages = with pkgs; [
            sysstat
        ];
    };
}
