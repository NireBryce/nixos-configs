{ ... }:

{
    # programs.vicinae = {
    #     enable = true;
    #     settings = {
            
    #     };
    #     systemd = {
    #         enable = true;
    #         autoStart = true;
    #     };
    programs.vicinae = {
        enable = true;
        autoStart = true;
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
