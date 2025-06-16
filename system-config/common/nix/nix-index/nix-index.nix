{
    ...
}:

{
    #todo: fix nix-index for flakes
    programs.nix-index.enable = true;
    programs.nix-index-database.enable = true;
}

# make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
