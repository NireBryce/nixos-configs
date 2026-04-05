{
    description = "cht.sh - cli cheatsheets";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            cheat
        ];
    };
}
