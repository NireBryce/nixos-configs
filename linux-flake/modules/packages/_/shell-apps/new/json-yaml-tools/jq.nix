{
    description = "jq https://github.com/stedolan/jq";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            jq
        ];
    };
}
