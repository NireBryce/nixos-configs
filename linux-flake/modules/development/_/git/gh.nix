{
    description = "gh - github-cli";
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            gh
        ];
    };
}
