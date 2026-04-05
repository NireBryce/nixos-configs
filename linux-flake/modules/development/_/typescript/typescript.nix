{
    description = "typescript";
    
    homeManager = 
    { pkgs, ... }:
    {   
        home.packages = with pkgs; [
            typescript
        ];
    };
}
