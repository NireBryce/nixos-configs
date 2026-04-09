{
    description = "neofetch replacement https://github.com/hykilpikonna/HyFetch";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            hyfetch
        ];
    };
}
