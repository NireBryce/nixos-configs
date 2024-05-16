# custom-iso.nix

{ nixpkgs ? <nixpkgs>, system ? "x86_64-linux" }:

let
  myisoconfig = { pkgs, ... }: {
    imports = [
      "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma5.nix"
    ];

    # services.openssh = {
      # enable = true;
      # passwordAuthentication = false;
      # allowSFTP = false; # Don't set this if you need sftp
      # challengeResponseAuthentication = false;
      # extraConfig = ''
      #   AllowTcpForwarding yes
      #   X11Forwarding no
      #   AllowAgentForwarding no
      #   AllowStreamLocalForwarding no
      #   AuthenticationMethods publickey
      # '';
    # };
    services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
        settings.KbdInteractiveAuthentication = false;
        allowSFTP = false; # Don't set this if you need sftp
        # challengeResponseAuthentication = false; # folded into settings.KbdInteractiveAuthentication
        
        extraConfig = ''
          AllowTcpForwarding yes
          X11Forwarding no
          AllowAgentForwarding no
          AllowStreamLocalForwarding no
          AuthenticationMethods publickey
        '';
      };
    environment.systemPackages = [
      pkgs.vim
      pkgs.zellij
      pkgs.gh
      pkgs.git
      pkgs.micro
      pkgs.nil
      pkgs.disko
      pkgs.firefox
      pkgs.tree
      pkgs.fd
    ];
    users.users = { 
        elly = {
          isNormalUser = true;
          extraGroups = [ "wheel" ]; # Enable ‘sudo’.
          packages = with pkgs; [ 
          #####
          # these are bootstrap/in case something goes wrong.
          # otherwise configured via fleek/home-manager
          #####
            firefox
            git
            micro
            tree
            vim
            zellij
            gh
            nil
            disko
         ];
        openssh.authorizedKeys.keys = [ 
          ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea'' 
          ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal''
          ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrl5HoGmaeht/D6J/uZWyhpB04huXARmgoKJABuOw6 elly@nire-galatea''
          ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif''
          ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost''
    
        ];
          hashedPassword = "$6$vW.dy.yEr7UN129D$ayl0LH0uYlmPsfL2fFbrSmiT5F8I5Np6Kmy/jW7RzDfSLs95Q4THYBagSxSeRbPdDwwjzDOLKexIQcSmgVePN0";
        };
      };
  };

  evalNixos = configuration: import "${nixpkgs}/nixos" {
    inherit system configuration;
  };


in 
{ 
  iso = (evalNixos myisoconfig).config.system.build.isoImage; 
}

