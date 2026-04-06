{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [ 
            mullvad-vpn
            tailscale                   # TODO: move to module
        ];
    };
}
