{ config, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{ 
  imports = 
  [ 
    ../common
    ./hardware-configuration.nix
    ./impermanence.nix
    ./graphical-environment.nix
    ./syncthing.nix
    ./sops.nix
    ./lysithea-users.nix
  ];
  
  

# hostname
  networking.hostName = "nire-galatea"; 

# Sops secret keys
  # sops.secrets.tailscale.key = {
  #   sopsFile = ../common/secrets.yml;
  # };

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # # Sound.
  # # TODO: Variablize
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;
  # Touchpad
  # # TODO: variablize 
  # # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # # Enable CUPS to print documents.
  # services.printing.enable = true;


  # # Some programs need SUID wrappers, can be configured further or are
  # # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };


  # # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?
}



