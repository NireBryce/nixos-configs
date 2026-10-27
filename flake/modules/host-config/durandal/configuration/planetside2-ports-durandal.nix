# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# Planetside 2's UDP ports, on the one host that plays it. They sat in
# networking.nix's shared allowedUDPPorts until 2026-10-19, opening the same
# LAN holes on cube (the always-on homelab server) and tenacity (the
# handheld) -- the same over-share lan-ports-closed-cube.nix narrows for KDE
# Connect and Steam. Everything here stays reachable over the tailnet
# regardless (tailscale0 is trusted, networking.nix).
{
    nixos = {
        # # description = "durandal: Planetside 2 UDP ports open on the LAN";
        networking.firewall.allowedUDPPorts = [
            24470
            25410
        ];
        networking.firewall.allowedUDPPortRanges = [
            {
                from = 20040;
                to = 20199;
            }
        ];
    };
}
