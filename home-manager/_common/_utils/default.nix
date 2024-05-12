# Many shell utils are configured via zi, which uses .zshrc as a declarative thingy
{
  imports = [ 
    ./_fzf.nix
    ./_home-manager.nix
    ./_micro.nix
  ];
}
