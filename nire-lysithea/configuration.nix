# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{
  imports =
    [ 
      "${impermanence}/nixos.nix"
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
    
  # TODO: variablize
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

# Impermanence
  # filesystems
    fileSystems."/".options = [ "compress=zstd" "noatime" ];
    fileSystems."/home".options = [ "compess=zstd" ];
    fileSystems."/nix".options = [ "compress=zstd" "noatime" ];
    fileSystems."/persist".options = [ "compress=zstd" "noatime" ];
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".options = [ "compress=zstd" "noatime" ];
    fileSystems."/var/log".neededForBoot = true;

# configure impermanence
  # TODO: variablize
  environment.persistence."/persist" = {
    directories = [
      "/etc/nixos"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      # "/etc/ssh/ssh_host_rsa_key"
      # "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
  # TODO: variablize
  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';

  


# Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
# TODO: uefi/bios switch
  boot.loader.efi.canTouchEfiVariables = true;

# Hostname
  # TODO: variablize
  networking.hostName = "nire-lysithea"; # Define your hostname.

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking

  # Set your time zone.
  time.timeZone = "America/New_York";
  

# Internationalisation properties.
  # TODO: variablize
  i18n.defaultLocale = "en_US.UTF-8";



# Enable the X11 windowing system.
  # TODO: x11/wayland switch
  services.xserver.enable = true;

# Enable the GNOME Desktop Environment.
  #TODO: variablize so it's a choice of DM and WM
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  


# User
  # Define a user account. Don't forget to set a password with ‘passwd’.
  # TODO: variablize
  users.users.elly = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      firefox
      tree
      micro
      git
    ];
    # TODO: variablize sshkey
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea" ];

    passwordFile = "/persist/passwords/user";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    coreutils
    micro # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    git
    bash
    zsh
  ];


# Firewall.
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


# shells
  environment.shells = [ 
                         pkgs.zsh
                         pkgs.bash
                       ];
  

  # List services that you want to enable:

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

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


  services.openssh = {
   enable = true;
   passwordAuthentication = false;
   allowSFTP = false; # Don't set this if you need sftp
   challengeResponseAuthentication = false;
   extraConfig = ''
     AllowTcpForwarding yes
     X11Forwarding no
     AllowAgentForwarding no
     AllowStreamLocalForwarding no
     AuthenticationMethods publickey
   '';
  };

# Erase the root at boot 1q
    boot.initrd = {
      enable = true;
      supportedFilesystems = [ "btrfs" ];

      systemd.services.restore-root = {
        description = "Rollback btrfs rootfs";
        wantedBy = [ "initrd.target" ];
        requires = [
          # TODO: variablize
          "dev-nvme0n1p3"
        ];
        after = [
          "dev-nvme0n1p3"
          "systemd-cryptsetup@${config.networking.hostName}.service"
        ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /mnt

          # We first mount the btrfs root to /mnt
          # so we can manipulate btrfs subvolumes.
          mount -o subvol=/ /dev/nvme0n1p3 /mnt

          # While we're tempted to just delete /root and create
          # a new snapshot from /root-blank, /root is already
          # populated at this point with a number of subvolumes,
          # which makes `btrfs subvolume delete` fail.
          # So, we remove them first.
          #
          # /root contains subvolumes:
          # - /root/var/lib/portables
          # - /root/var/lib/machines
          #
          # I suspect these are related to systemd-nspawn, but
          # since I don't use it I'm not 100% sure.
          # Anyhow, deleting these subvolumes hasn't resulted
          # in any issues so far, except for fairly
          # benign-looking errors from systemd-tmpfiles.
          btrfs subvolume list -o /mnt/root |
          cut -f9 -d' ' |
          while read subvolume; do
            echo "deleting /$subvolume subvolume..."
            btrfs subvolume delete "/mnt/$subvolume"
          done &&
          echo "deleting /root subvolume..." &&
          btrfs subvolume delete /mnt/root

          echo "restoring blank /root subvolume..."
          btrfs subvolume snapshot /mnt/root-blank /mnt/root

          # Once we're done rolling back to a blank snapshot,
          # we can unmount /mnt and continue on the boot process.
          umount /mnt
        '';
      };
    };

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

# Sound.
  # TODO: Variablize
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;
# Touchpad
  # TODO: variablize 
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

# Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

# Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # reset / at each boot
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };


  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
}


















