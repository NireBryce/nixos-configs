{ ... }:
{
  # TODO: have _zsh option toggle this on and off
  # TODO: historical
  home.shellAliases = { 
    "apply-nire-durandal" = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-durandal";
    
    "apply-nire-galatea" = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-galatea";
    
    "apply-nire-lysithea" = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-lysithea";
    };  # zsh config breaks this, 
                            # aliases need to be added after .zshrc eval
}
