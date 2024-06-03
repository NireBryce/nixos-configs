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
  };

  sops.secrets.tailscale_key = {
    sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  };
  # sops.secrets.ssh-elly-durandal = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.ssh-elly-galatea = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.ssh-elly-lysithea = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.ssh-elly-sif = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.ssh-elly-iona = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.syncthing-durandal = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.syncthing-galatea = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.syncthing-lysithea = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.syncthing-sif = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.syncthing-iona = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
  #   sops.secrets.syncthing-tenacity = {
  #   sopsFile =  ./_sys.sec.secrets/secrets.yaml; 
  # };
}

