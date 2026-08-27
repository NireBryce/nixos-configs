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
            # inactive, and no NixOS option starts it. NixOS's own libvirtd
            # module (systemd.services.libvirtd-config) already handles the
            # *definition* -- it re-copies the stock default.xml into
            # /var/lib/libvirt/qemu/networks/ on every boot if missing, so
            # that half survives an impermanence wipe for free. The other
            # half -- actually starting it -- is handled per-VM instead of
            # here: VMs/_lib/libvirt-vm.nix's activation script starts the
            # default network itself when a VM declares `networked = true`,
            # rather than a host-wide unit unconditionally bringing up
            # virbr0 (and the trustedInterfaces trust above) on every boot
            # regardless of whether anything ever uses it. A VM started by
            # hand instead -- outside that generator, e.g. via virt-manager
            # directly on durandal today -- still needs the old manual step:
            #
            #     virsh net-start default && virsh net-autostart default
            #
            # `virsh net-list --all` shows whether it took.
        };
}
