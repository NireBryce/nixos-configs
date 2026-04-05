{
    description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            gimp
        ];
    };
}
