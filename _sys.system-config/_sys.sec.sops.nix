{ 
  sops-nix, 
  config,
  ...
}:

# sops secret management

let
  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;

in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  

  sops = {
    age.sshKeyPaths = map getKeyPath keys;
    defaultSopsFile = ./_sys.sec.secrets/secrets.yaml;
    # TODO: figure out how to fix this to not require UUID hardcoding
      # defaultSymlinkPath = "/run/user/1000/secrets";
      # defaultSecretsMountPoint = "/run/user/1000/secrets.d";
  };

  sops.secrets.tailscale_key = {
    sopsFile        = ./_sys.sec.secrets/secrets.yaml; 
  };

  # SSH
    sops.secrets.ssh-durandal = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml;
    };
      sops.secrets.ssh-galatea = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml;
    };
      sops.secrets.ssh-lysithea = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml;
    };
      sops.secrets.ssh-sif = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
      sops.secrets.ssh-iona = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
  # Syncthing
    sops.secrets.syncthing-durandal = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 

    };
      sops.secrets.syncthing-galatea = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
      sops.secrets.syncthing-lysithea = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
      sops.secrets.syncthing-sif = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
      sops.secrets.syncthing-iona = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
      sops.secrets.syncthing-tenacity = {
      sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
    };
}

