# note: may need to be inputs and then inputs.self, see https://github.com/Doc-Steve/dendritic-design-with-flake-parts/blob/main/modules/hosts/homeserver%20%5BN%5D/flake-parts.nix
{ 
    self, 
    ... 
}:
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

flake.nixosConfigurations = self.lib.mkNixos "x86_64-linux" "nire-durandal";

flake.modules.nixos."nire-durandal" = 
{import-tree, nix-index-database, ...}:
{
    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    networking.hostName = "nire-durandal";

    imports = [
        nix-index-database.nixosModules.nix-index
        ../misc/modules/linux-crisis-utilities.nix
        (import-tree ./configs/hosts/nire-durandal/hw-conf)
        (import-tree ./configs/hosts/nire-durandal/fixes)
        (import-tree ./configs/system-config)
        # impermanence
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        ./configs/system-config/impermanence/_WARN.impermanence.nix
    ];

};
}
