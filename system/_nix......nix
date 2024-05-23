{
  ...
}:

# nix settings metapackage
{
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;
}
