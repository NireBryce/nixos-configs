{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { ... }: {
            # # description = "let libvirt's NAT bridge past the host firewall";

            # libvirt's default network is NAT behind `virbr0`, with libvirt's own
            # dnsmasq handing out DHCP leases and answering DNS on the bridge
            # address. The host firewall is on here (networking.firewall.enable is
            # true on every host in this repo), and it drops those guest-to-host
            # packets, so the symptom is a guest that boots fine, gets no lease,
            # and looks like a broken NIC rather than a firewall problem.
            #
            # trustedInterfaces is `listOf str` and concatenates rather than
            # overrides, so this adds to the tailscale0/lo already set elsewhere
            # instead of replacing them -- the same merge behaviour that made the
            # duplicate "podman" group in nire/containers/podman/podman.nix
            # (nire/system/containers/ until 2026-08-22), useful here.
            #
            # The tradeoff is real and worth knowing: trusting the interface means
            # the host accepts *anything* from a guest on it, so a compromised
            # guest reaches every port on the host. Homelab call. The narrower
            # version is to leave it untrusted and open only 53 and 67 on virbr0
            # with networking.firewall.interfaces."virbr0".allowedUDPPorts.
            networking.firewall.trustedInterfaces = [ "virbr0" ];

            # Two things this module deliberately does NOT set:
            #
            # virtualisation.libvirtd.allowedBridges already defaults to
            # [ "virbr0" ] in nixpkgs, and it is what libvirt writes
            # /etc/qemu/bridge.conf from -- qemu-bridge-helper refuses any bridge
            # not named there. Restating the default buys nothing. Add to it only
            # when a guest needs to sit on the LAN directly instead of behind NAT,
            # at the same time as the netdev that uses it.
            #
            # Whether the default network actually runs is *runtime* state in
            # /var/lib/libvirt, not config -- libvirt ships the definition
            # inactive, and no NixOS option starts it. Once per host:
            #
            #     virsh net-start default && virsh net-autostart default
            #
            # `virsh net-list --all` shows whether it took.
        };
}
