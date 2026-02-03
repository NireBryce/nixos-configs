{ ... }:
{
    
 # Set the capability flags for this machine at the flake level
    config.my.roles = {
        develop     = true;
        gaming      = true;
        notMinimal  = true;
        amdCpu      = true;
        amdGpu      = true;
        wmKde       = true;
        wmWayland   = true;
        impermanent = true; # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        user-elly   = true;
    };
  # The NixOS module for this machine

  nixosConfigurations."nire-durandal" = inputs.nixpkgs.lib.nixosSystem {
          specialArgs = inputs;
          modules     = [
            ./hosts/nire-durandal/durandal-host-config.nix
          ];
        };
flake.modules.nixos.nire-durandal = 
{import-tree, nix-index-database, ...}:
{
    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    networking.hostName = "nire-durandal";
    
    imports = 
    let 
        user = "elly"; host = "nire-durandal"; 
        wm = "kde"; cpu = "amd"; gpu = "amd"; 
    in 
    [
        (import-tree ../misc/util/nix) # utility functions
        nix-index-database.nixosModules.nix-index
        ../misc/modules/linux-crisis-utilities.nix
        (import-tree ./configs/hosts/${host})
        (import-tree ./configs/system-config/users/${user})
        (import-tree ./configs/system-config/hw/gpu/${gpu})
        (import-tree ./configs/system-config/hw/cpu/${cpu})
        (import-tree ./configs/system-config/common)
        (import-tree ./configs/system-config/gaming)
        (import-tree ./configs/system-config/wm/${wm})
        # impermanence
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        ./configs/system-config/impermanence/_WARN.impermanence.nix
    ];

};
}
