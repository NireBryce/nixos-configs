{ 
    description = "bitwarden - password manager https://bitwarden.com/";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            bitwarden-desktop
        ];
    };
}
