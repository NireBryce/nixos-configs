{
    ...
}:
{
    flake.modules.nixos.nix-utils = { ... }: {
        programs.nix-index-database.comma.enable = true;
    };
}
