{
    description = "make nix fetcher calls from repository URLs";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nurl
        ];
    };
}
