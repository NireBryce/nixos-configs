{
    description ="kanata - input-level keybinding, platform independent";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            kanata
        ];
    };
}
