{ 
  pkgs, 
  config,
  ... 
}:
{
  # User
  users.mutableUsers = false;
  users.users = { 
    elly = {
      shell = pkgs.zsh;
      isNormalUser = true;
      extraGroups = [ "wheel" "audio" ]; # Enable ‘sudo’ and deeper audio access
      hashedPasswordFile = "/persist/passwords/elly";
      packages = with pkgs; [ 
        # Emergency packages if home-manager dies
        firefox
        git
        gh
        micro
        tree
      ];
      # openssh.authorizedKeys.keyFiles = [
      # # TODO: figure out how to get the key from a sops path and put these in sops 
      #   config.sops.secrets.ssh-durandal.path
      #   config.sops.secrets.ssh-galatea.path
      #   config.sops.secrets.ssh-lysithea.path
      #   config.sops.secrets.ssh-sif.path
      #   config.sops.secrets.ssh-iona.path
      # ];
      openssh.authorizedKeys.keys = [ 
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea'' 
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal''
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrl5HoGmaeht/D6J/uZWyhpB04huXARmgoKJABuOw6 elly@nire-galatea''
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif''
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost''
      ];
    };
  };
}
