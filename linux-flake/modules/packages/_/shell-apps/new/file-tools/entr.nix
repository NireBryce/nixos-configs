{
    description = "run commands when file changes";
    
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            entr
        ];
    };
}
