{ 
    description = "network monitor https://pdw.ex-parrot.com/iftop/";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            iftop
        ];
    };
}
