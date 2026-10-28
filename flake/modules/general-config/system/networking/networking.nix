# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ 
    nixos = {
        # DNS
        # networking.nameservers = [
        #     "1.1.1.1"
        #     "1.0.0.1"
        # ];

        # Firewall
        networking.firewall = {
            enable = true;
            # TCP: nothing here. ssh's port 22 comes from
            # services.openssh.openFirewall (default true), so a host can
            # close it with that one option -- tenacity does
            # (ssh-tailnet-only-tenacity.nix); listing 22 here too would
            # reopen it. KDE Connect's 1714-1764 (TCP and UDP) come from
            # programs.kdeconnect (kde-connect.nix).
            # UDP
            allowedUDPPorts = [
                5353 # mdns
                # tailscale's own port is opened by services.tailscale.openFirewall
                # in tailscale.nix, not listed here.
            ];
            # Planetside 2's ports (24470, 25410, 20040-20199) moved to
            # planetside2-ports-durandal.nix on 2026-10-19: this category
            # reaches every host, and only durandal plays.

            trustedInterfaces = [
                "tailscale0" # always allow traffic from your Tailscale network
            ];
        };
    };
}
