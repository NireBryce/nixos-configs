{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # `{ ... }:` kept over statix's suggested `_:` -- deliberate, see
        # wiki/module-style-guide.md's "`{ ... }:` on an inner module lambda".
        flake.modules.nixos.${moduleName} = { ... }: {
            # # description = "let libvirt's NAT bridge past the host firewall";

            # libvirt's default network is NAT behind `virbr0`, with libvirt's own
            # dnsmasq handing out DHCP leases and answering DNS on the bridge
            # address. The host firewall is on here (networking.firewall.enable is
            # true on every host in this repo), and it drops those guest-to-host
            # packets, so the symptom is a guest that boots fine, gets no lease,
            # and looks like a broken NIC rather than a firewall problem.
            #
            # 2026-09-25: narrowed from `trustedInterfaces = [ "virbr0" ]`
            # (concatenating, additive to tailscale0/lo) when the runner VM
            # landed -- blanket trust meant a compromised guest reached
            # every port on the host, and this host now RUNS job code.
            # Guests get exactly: DHCP leases and DNS from libvirt's
            # dnsmasq, and Caddy's 80/443 (the forge door). Per-interface
            # options scope the accepts to virbr0 traffic only; everything
            # else a guest sends the host hits the firewall's default
            # reject. Established/related replies pass as always. Guest
            # egress (the other direction) is the runner guest's own
            # OUTPUT policy -- git-forge/forgejo/actions-runner.nix's
            # guest config, not this module.
            networking.firewall.interfaces."virbr0" = {
                allowedUDPPorts = [ 53 67 ];   # dnsmasq: DNS + DHCP
                allowedTCPPorts = [ 80 443 ];  # Caddy: the forge door
            };

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
