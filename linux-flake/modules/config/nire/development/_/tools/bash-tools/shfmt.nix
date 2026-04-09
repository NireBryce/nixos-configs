{
    description = "shellfmt shellscript formatter";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            shfmt
        ];
    };
}
