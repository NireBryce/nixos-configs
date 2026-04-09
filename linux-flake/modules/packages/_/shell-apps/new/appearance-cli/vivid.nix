{
    description = "vivid - LS_COLORS generator";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            vivid
        ];
    };
}
