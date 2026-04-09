{
    description = "nixd lsp";
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nixd
        ];
    };
}
