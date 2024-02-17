{ pkgs, ... }:
{
  users.users.elly = {
      openssh.authorizedKeys.keys = [ ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea'' 
                                      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal''
                                      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLrl5HoGmaeht/D6J/uZWyhpB04huXARmgoKJABuOw6 elly@nire-galatea''
                                      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif''
                                    ];
      hashedPasswordFile = "/persist/passwords/user";
    };

}
