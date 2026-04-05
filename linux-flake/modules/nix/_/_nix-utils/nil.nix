{
    description = "nil - a nix LSP server";
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nil
        ];
    };
}
