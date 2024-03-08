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
      packages = with pkgs; [ # Otherwise configured via fleek/home-manager
        firefox
        git
        micro
        tree
      ];
    };
  };
}
