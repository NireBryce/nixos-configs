{ 
  imports = [
    # need to make this not bound to a particular partition scheme
    ./_delete-root.nix
    ./_drives.nix
    ./_impermanence.nix
  ];

}
