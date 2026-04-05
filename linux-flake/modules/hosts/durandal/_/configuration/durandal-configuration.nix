{
    # TODO: separate out hosts from /modules so it is more obvious this is where the module are loaded
    nixos = 
    {
        imports = [
            <nire/desktop-env>
            <nire/development>
            <nire/editors>
            <nire/hardware>
            <nire/impermanence>
            <nire/nix>
            <nire/packages>
            <nire/peripherals>
            <nire/shell-config>
            <nire/system>
            <nire/users>
        ];
        
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        networking.hostName = "nire-durandal";
    };
}
