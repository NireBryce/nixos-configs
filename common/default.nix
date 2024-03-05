{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    # ./acme.nix
    # need to make this not bound to a particular partition scheme
    ./impermanence.nix
    ./users.nix
    ./ssh.nix
    ./sound.nix
    ./bluetooth.nix
    # ./tailscale.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.efi.efiSysMountPoint = "/boot";  
  # wifi manager options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  
  environment.etc.machine-id.source = /persist/etc/machine-id;
  
  # Set time zone.
  time.timeZone = "America/New_York";
  
  # i18n
  i18n.defaultLocale = "en_US.UTF-8";

  programs.kdeconnect.enable = true;

  # bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  # services.blueman.enable = true;
  
# system packages
  # List packages installed in system profile. To search, run:
  # $ nix search <package name>
  environment.systemPackages = with pkgs; [
    coreutils
    micro # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    git
    bash
    zsh
    stdenv
    gcc
    # pkgs.kdePackages.kdeconnect-kde
    # pkgs.kdePackages.plasma-pa
    # pkgs.kdePackages.baloo
    # pkgs.kdePackages.baloo-widgets
    # pulseaudio    
  ];

# Needed for VSCode remote connection
  programs.nix-ld.enable = true;

# shells
  environment.shells = [ 
                          pkgs.zsh
                          pkgs.bash
                       ];
  

  
  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [          
                        22 # ssh
                      ];
    allowedTCPPortRanges = [  
                            {  # kde-connect TCP
                              from = 1714;
                              to   = 1764;    
                            }
                           ];
    allowedUDPPorts = [                            
                        
                      ];
    allowedUDPPortRanges = [
                            { # kde-connect UDP 
                              from = 1714;
                              to   = 1764;
                            }   
                           ];
  };

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };




}
