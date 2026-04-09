{
    description = "an application to show file info";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            file
        ];
    };
}
