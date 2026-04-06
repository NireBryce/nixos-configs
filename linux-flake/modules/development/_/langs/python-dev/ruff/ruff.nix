{
    description = "ruff - python linter";
    
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            ruff
        ];
    };
}
