{
    description = "shellcheck shellscript linter";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            shellcheck
        ];
    };
}
