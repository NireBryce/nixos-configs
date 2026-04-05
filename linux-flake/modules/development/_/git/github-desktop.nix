{
    description = "github-desktop - github gui"; 
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            github-desktop
        ];
    };
}
