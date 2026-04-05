{
    description = "`du` alternative";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            dust
        ];
    };
}
