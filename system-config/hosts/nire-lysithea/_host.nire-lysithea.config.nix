# MacOS
{
  self,
  nixpkgs,
  lib,
  ...
}:

let flakePath = self;
in {
  imports = [

    # system packages
    "${flakePath}/system-config/hosts/nire-lysithea/lysithea-system-packages.nix"

    # from common defaults
    "${flakePath}/system-config/_sys.bash.nix"
    # "${flakePath}/system-config/_sys.sec.sops.nix"
    "${flakePath}/system-config/_sys.shells.nix"
  ];

  # TODO: nix-index workaround potentially deprecated refer to darwin section of flake
  # $NIX_PATH
    # nix.nixPath = [                                           # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
    #   "nixpkgs=${nixpkgs}"
    #   "/nix/var/nix/profiles/per-user/root/channels"
    # ];
  

  programs.zsh.enable = true;
  programs.zsh.enableCompletion = lib.mkForce false;    # Handled in home-manager, otherwise this calls compaudit

  # nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; 
  services.nix-daemon.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;
  
  # Used for backwards compatibility, please read the changelog before changing.
  #   $ darwin-rebuild changelog
  system.stateVersion = 4;
  nixpkgs.hostPlatform = "aarch64-darwin";

  


} 
