{
  config,
  pkgs,
  impermanence,
  lib,
  ...
}: 

{
  imports = [
    impermanence.nixosModule
  ];

# configure impermanence
  # TODO: variablize
  environment.etc.machine-id.source = /persist/etc/machine-id;
  environment.persistence."/persist" = {
    directories = [
      # "/etc/nixos" # no longer needed with the flake.
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      # { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
      
    ];
    files = [
      # "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      # { file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
    ];
  };
  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';

}
