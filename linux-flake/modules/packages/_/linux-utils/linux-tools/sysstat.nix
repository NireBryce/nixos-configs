{
    description = "system stats http://sebastien.godard.pagesperso-orange.fr/";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            sysstat
        ];
    };
}
