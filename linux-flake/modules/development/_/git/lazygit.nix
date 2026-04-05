{
    description = "lazygit - TUI git interface";
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            lazygit
        ];
    };
}
