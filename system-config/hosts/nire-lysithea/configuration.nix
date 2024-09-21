# MacOS
{
  self,
  pkgs,
  lib,
  ...
}:

let flakePath = self;
in {
  # Used for backwards compatibility, please read the changelog before changing: `darwin-rebuild changelog`
    system.stateVersion = 4;
    nixpkgs.hostPlatform = "aarch64-darwin";
    
    imports = [
      # system packages
        "${flakePath}/system-config/hosts/nire-lysithea/lysithea-system-packages.nix"
      # from common defaults
        "${flakePath}/system-config/_sys.bash.nix"
      # "${flakePath}/system-config/_sys.sec.sops.nix"
        "${flakePath}/system-config/_sys.shells.nix"
    ];
  # nix settings
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true; 
    services.nix-daemon.enable = true;

  # Set Git commit hash for darwin-version.
    system.configurationRevision = self.rev or self.dirtyRev or null;


  
    programs.zsh.enable = true;
    programs.zsh.enableCompletion = lib.mkForce false;    # Handled in home-manager, otherwise this calls compaudit

    environment.systemPackages = with pkgs; [ # Always have an editor here
        # bash                                          # bash.  ok i guess.
        coreutils                                     # coreutils
        curl                                          # curl
        gcc                                           # gcc
        git                                           # git
        micro                                         # micro
        stdenv                                        # stdenv
        wget                                          # wget
        zoxide                                        # zoxide
        ripgrep                                       # ripgrep
        nix-output-monitor                            # `nom` nix-output-monitor  https://github.com/maralorn/nix-output-monitor
        nh                                            # nix helper                https://github.com/viperML/nh
        sops                                          # secret management
    ];


} 


# TODO: move to home-manager
  # programs.nh = {                                   # `nh` nix-helper           https://github.com/viperML/nh
  #     enable = true;
  #     clean.enable = true;
  #     clean.extraArgs = "--keep-since 7d --keep 5";
  #     flake = "/Users/elly/nixos";
  #   };

    # programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database
# TODO: fixme for darwin
  # fonts.packages = with pkgs; [
  #   (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" ];})  # be not afraid
  # ];
# TODO: nix-index workaround potentially deprecated refer to darwin section of flake
# $NIX_PATH
  # nix.nixPath = [                                           # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
  #   "nixpkgs=${nixpkgs}"
  #   "/nix/var/nix/profiles/per-user/root/channels"
  # ];
