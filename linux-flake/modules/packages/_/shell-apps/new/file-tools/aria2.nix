{
    description = "aria2 -cli download manager";
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            aria2
        ];
    };
}
