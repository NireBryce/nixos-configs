{
    description = "yazi - file browser";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            yazi
        ];
    };
}
