{ 
  sops-nix, 
  config,
  self,
  ...
}:

# sops secret management

let
  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;

  secretsPath = "${self}/system-config/secrets/secrets.yaml";

in {
  imports = [
    sops-nix.nixosModules.sops
  ];

  

  sops = {
    age.sshKeyPaths = map getKeyPath keys;
    defaultSopsFile = "${secretsPath}/secrets.yaml";
    # TODO: figure out how to fix this to not require UUID hardcoding
      # defaultSymlinkPath = "/run/user/1000/secrets";
      # defaultSecretsMountPoint = "/run/user/1000/secrets.d";
  };

  sops.secrets.tailscale_key = {
    sopsFile        = "${secretsPath}"; 
  };

  # SSH
    # sops.secrets.ssh-durandal = {
    #   sopsFile =  "${secretsPath}";
    # };
    #   sops.secrets.ssh-galatea = {
    #   sopsFile =  "${secretsPath}";
    # };
    #   sops.secrets.ssh-lysithea = {
    #   sopsFile =  "${secretsPath}";
    # };
    #   sops.secrets.ssh-sif = {
    #   sopsFile =  "${secretsPath}"; 
    # };
    #   sops.secrets.ssh-iona = {
    #   sopsFile =  "${secretsPath}"; 
    # };
  # Syncthing
    sops.secrets.syncthing-durandal = {
      sopsFile =  "${secretsPath}"; 

    };
      sops.secrets.syncthing-galatea = {
      sopsFile =  "${secretsPath}"; 
    };
      sops.secrets.syncthing-lysithea = {
      sopsFile =  "${secretsPath}"; 
    };
      sops.secrets.syncthing-sif = {
      sopsFile =  "${secretsPath}"; 
    };
      sops.secrets.syncthing-iona = {
      sopsFile =  "${secretsPath}"; 
    };
      sops.secrets.syncthing-tenacity = {
      sopsFile =  "${secretsPath}"; 
    };
}

