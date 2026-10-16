# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # system stats http://sebastien.godard.pagesperso-orange.fr/
        home.packages = with pkgs; [
            sysstat
        ];
    };
}
