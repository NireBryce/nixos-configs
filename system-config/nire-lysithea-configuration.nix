# MacOS
{
  self,
  pkgs,
  lib,
  ...
}:

{
  # Used for backwards compatibility, please read the changelog before changing: `darwin-rebuild changelog`
    system.stateVersion = 4;
    nixpkgs.hostPlatform = "aarch64-darwin";

  # nix settings
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true; 
    services.nix-daemon.enable = true;

  # Set Git commit hash for darwin-version.
    system.configurationRevision = self.rev or self.dirtyRev or null;
  

  ## shells
    environment.shells = with pkgs; [
        bash
        zsh
    ];
  
  #? Make sure system completions work even with home-manager managed shells 
    environment.pathsToLink = [   
        "/share/zsh"
        "/share/bash-completion"
        "/share/fish"
    ];
  
  #? zsh is handled through home-manager
    programs.zsh.enable = true;
    programs.zsh.enableCompletion = lib.mkForce false;  # unless disabled, home-manager causes an extra compaudit
  
    programs.bash.interactiveShellInit = ''
        ${pkgs.inshellisense}/bin/inshellisense;
    '';
  ## System packages
    environment.systemPackages = with pkgs; [ # Always have an editor here
      #* System utilities
        # bash                                           # ok. i guess.
          #? Bash Plugins
            inshellisense                       # menu-complete and auto-suggest
            starship                            # theming
            blesh                               # if bash were zsh
        coreutils                                     # coreutils
        gcc                                           # gcc
        git                                           # git
        micro                                         # micro
        stdenv                                        # stdenv
        wget                                          # wget
        curl                                          # curl
        zoxide                                        # zoxide
        ripgrep                                       # ripgrep
        nix-output-monitor                            # `nom` nix-output-monitor  https://github.com/maralorn/nix-output-monitor
        nh                                            # nix helper                https://github.com/viperML/nh
        sops                                          # secret management
    ];
} 





# TODO: move to home-manager / fix for darwin
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
