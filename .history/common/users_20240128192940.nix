{ pkgs, ... }:
{
# User
  # Define a user account. Don't forget to set a password with ‘passwd’.
  # TODO: variablize
  users.mutableUsers = false;
  users.users = { 
    elly = {
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

      hashedPasswordFile = "/persist/passwords/user";
    };
  };
}
