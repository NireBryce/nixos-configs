{
    description = "libreoffice - office productivity software https://www.libreoffice.org/";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            libreoffice-qt
        ];
    };
}
