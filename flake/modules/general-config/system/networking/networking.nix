{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = {
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
                    24470 # planetside2
                    25410 # planetside2
                    # tailscale's own port is opened by services.tailscale.openFirewall
                    # in tailscale.nix, not listed here.
                ];
                allowedUDPPortRanges = [
                    {
                        # planetside2
                        from = 20040;
                        to = 20199;
                    } 
                ];

                trustedInterfaces = [
                    "tailscale0" # always allow traffic from your Tailscale network
                ];
            };
        };
}
