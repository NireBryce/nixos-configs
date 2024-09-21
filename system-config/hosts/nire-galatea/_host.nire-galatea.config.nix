{ 
  nixos-hardware,
  self,
  ... 
}: 

let flakePath = self;
in {
  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-x270 
                                                
      # TODO: make look like home-manager via let/in
    # Users
    # ../.usr.elly.nix # modularize this later

    # window-manager
    # "${flakePath}/system-config/_sys.wm.kde.nix"        # KDE

    # nix generated
    "${flakePath}/system-config/hosts/nire-galatea/hardware-configuration.nix"
    "${flakePath}/system-config/hosts/nire-galatea/stateVersion.nix"

    # networking
    "${flakePath}/system-config/_sys.sec.sops.nix"                          # Secret management
    
    # firewall and ssh
    "${flakePath}/system-config/hosts/nire-galatea/firewall.nix"
    "${flakePath}/system-config/hosts/nire-galatea/ssh.nix"
    
    # hardware


    # defaults and imports
    "${flakePath}/system-config/configuration.nix"

    # users
    "${flakePath}/system-config/users/elly/_sys.elly.nix"
    
    # fixes

  ];

  # hostname
  networking.hostName = "nire-galatea";

}
