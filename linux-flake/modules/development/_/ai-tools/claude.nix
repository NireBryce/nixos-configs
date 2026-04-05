{
    
    description = "claude code";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            claude-code
        ];
    };
}

