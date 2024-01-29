{ pkgs, ... }:
{
  users.users.elly = {
      openssh.authorizedKeys.keys = [  ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrl5HoGmaeht/D6J/uZWyhpB04huXARmgoKJABuOw6 elly@nire-galatea''  ];
      hashedPasswordFile = "/persist/passwords/elly";
    };

}
