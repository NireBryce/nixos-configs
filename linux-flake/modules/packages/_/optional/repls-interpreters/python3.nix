{ 
    description = "home-manager instance of python3";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            python3
        ];
    };
}
