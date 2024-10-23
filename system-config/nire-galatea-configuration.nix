{ 
  nixos-hardware,
  pkgs,
  lib,
  self,
  ... 
}: 

let flakePath = self;
in let 
    # networking-tailscale = "${flakePath}/system-config/services/__tailscale.nix";
    _hardware-configuration = "${flakePath}/system-config/hardware-configurations/galatea-hardware-configuration.nix";
    _sops-secrets           = "${flakePath}/system-config/secrets/_sops.nix";
    _user-elly              = "${flakePath}/system-config/users/_elly.nix";
    linux-crisis-utils      = "${flakePath}/___modules/linux-crisis-utilities.nix";

in {
  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-x270 
    _hardware-configuration
    _sops-secrets
    _user-elly
    linux-crisis-utils
    # users
    
    "${flakePath}/___modules/linux-crisis-utilities.nix"


  ];

  # hostname
    networking.hostName = "nire-galatea";

  # ssh
    services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
        settings.KbdInteractiveAuthentication = false;
        allowSFTP = false; # Don't set this if you need sftp
        extraConfig = ''
          AllowTcpForwarding yes
          X11Forwarding no
          AllowAgentForwarding no
          AllowStreamLocalForwarding no
          AuthenticationMethods publickey
        '';
    };
    users.users.elly = { 
        openssh.authorizedKeys.keys = [ # TODO: sopsify or something for belt and suspenders because @munin gets antsy when I link this
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea'' 
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal''
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif''
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost''
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea''
        ];
    };

  ## Firewall
    networking.firewall = { 
        enable = true;
        allowedTCPPorts = [
            22  # ssh
        ];
        allowedTCPPortRanges = [  
          # kde-connect TCP
            { from = 1714; to = 1764; }
        ];
        allowedUDPPorts = [                            
        ];
        allowedUDPPortRanges = [
          # kde-connect UDP 
            { from = 1714; to = 1764; }   
        ];
    };

  
  ## system packages
  
    # programs.kdeconnect.enable = true;    # kde connect
    # programs.xwayland.enable = true;      # xwayland

    services.fwupd.enable = true;         # fwupd
    programs.nix-ld.enable = true;        # Needed for VSCode remote connection
    programs.nh = {                                   # `nh` nix-helper           https://github.com/viperML/nh
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 7d --keep 5";
        flake = "/home/elly/nixos";
    };

    fonts.packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" ];})  # be not afraid
    ];
    
    environment.systemPackages = with pkgs; [ # Always have an editor here
        bash                                          # bash.  ok i guess.
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
        linuxHeaders                                  # linux headers
        sops                                          # secret management
    ];

    programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database

  ## nixos state version
    # don't change this
    # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "23.11"; # Did you read the comment?
}
