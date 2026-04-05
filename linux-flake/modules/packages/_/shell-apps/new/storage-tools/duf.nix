{
    description = "`df` alternative";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            duf
        ];
    };
}
