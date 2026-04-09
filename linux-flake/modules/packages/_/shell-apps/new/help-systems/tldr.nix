{
    description = "tldr - community provided man pages";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            tldr
        ];
    };
}
