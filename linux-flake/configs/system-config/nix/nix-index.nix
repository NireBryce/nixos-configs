{
    ...
}:
{
    flake.modules.nixos.nix-utils = { pkgs, ... }: {
        # this barely works. figure out why
        programs.nix-index.enable = true;
    };
}

# make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
