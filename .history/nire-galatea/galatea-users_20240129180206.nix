{ pkgs, ... }:
{
  users.users.elly = {
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea" ];
      hashedPasswordFile = "/persist/passwords/elly";
    };

}
