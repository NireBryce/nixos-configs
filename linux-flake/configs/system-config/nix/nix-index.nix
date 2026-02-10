{
    ...
}:
{
den.bundles.nix-packages = { ... }:  
{
        # this barely works. figure out why
        programs.nix-index.enable = true;
}
;}

# make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
