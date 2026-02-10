{ den.bundles.hm.command-runners =
{ ... }:
{
    programs.vicinae = {
        enable = true;
        systemd = {
            enable = true;
            autoStart = true;
        };
        settings = {
            faviconService = "twenty"; # twenty | google | none
            font.size = 11;
            popToRootOnClose = false;
            rootSearch.searchFiles = false;
            theme.name = "vicinae-dark";
            window = {
                csd = true;
                opacity = 0.95;
                rounding = 10;
            };
        };
    };
}
;}
