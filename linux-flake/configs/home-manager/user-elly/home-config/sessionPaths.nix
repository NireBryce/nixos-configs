# desc = "elly user session paths";
{ den.bundles.hm.homeConfig =
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
}
;}
