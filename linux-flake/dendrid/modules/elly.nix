{ den, ... }:
{
  den.hosts.x86_64-linux.nire-durandal.users.elly = { };
  den.hosts.aarch64-darwin.nire-lysithea.users.elly = { };
  
  den.aspects.elly = {
    includes = [
      den.provides.primary-user
      (den.provides.user-shell "bash")
    ];

    homeManager = { import-tree, ... }: {
      home.stateVersion        = "22.11"; 
      home.username            = "elly";
      home.homeDirectory       = "/home/elly";
      imports = [
        (import-tree ./configs/home-manager/user-elly)
      ];
    };

    # user can provide NixOS configurations
    # to any host it is included on
    # nixos = { pkgs, ... }: { };
  };
}
