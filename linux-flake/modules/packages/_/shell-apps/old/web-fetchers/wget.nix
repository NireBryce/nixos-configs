{
    description = "its like curl but different https://www.gnu.org/software/wget/";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            wget
        ];
    };
}
