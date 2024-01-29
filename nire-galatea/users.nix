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
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICg98bz8ZEsVJSQ/AY3ReGHUo1DGJnAMJtNPDHKiRy99 elly" ];

      hashedPasswordFile = "/persist/passwords/user";
    };
  };
}
