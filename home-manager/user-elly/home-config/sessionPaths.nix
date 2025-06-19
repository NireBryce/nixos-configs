{ ... }:
{
    description = "elly user session paths";
    flake.modules.homeManager.base =
    { ... }:
    {
        home.sessionPath = [ 
            "/usr/local"
            "/usr/bin"
            "$HOME/bin"
            "$HOME/.local/bin"
            "$HOME/.nix-profile/bin"
            "$HOME/.zi/bin"
            "$HOME/.config/zi/bin"
            "$HOME/.cargo/bin"
        ];
    };
}
