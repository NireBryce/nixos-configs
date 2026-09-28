{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # `{ ... }:` kept over statix's suggested `_:` -- deliberate, see
        # wiki/module-style-guide.md's "`{ ... }:` on an inner module lambda".
        flake.modules.nixos.${moduleName} = { ... }: {
            # # description = "let libvirt's NAT bridge past the host firewall";

            # libvirt's default network is NAT behind `virbr0`, with libvirt's own
            # dnsmasq handing out DHCP leases (and DNS, which guests here are
            # refused -- below) on the bridge address. The host firewall is on here (networking.firewall.enable is
            # true on every host in this repo), and it drops those guest-to-host
            # packets, so the symptom is a guest that boots fine, gets no lease,
            # and looks like a broken NIC rather than a firewall problem.
            #
            # 2026-09-25: narrowed from `trustedInterfaces = [ "virbr0" ]`
            # (concatenating, additive to tailscale0/lo) when the runner VM
            # landed -- blanket trust meant a compromised guest reached
            # every port on the host, and this host now RUNS job code.
            # Guests get exactly: DHCP leases from libvirt's dnsmasq, and
            # Caddy's 443 on the bridge address only (the forge door; which
            # vhosts answer a guest is caddy.nix's `vmDeny`) -- not on the
            # host's LAN or tailnet addresses. Established/related replies
            # pass as always.
            #
            # DNS goes to vm-egress-dns.nix's allowlisting resolver on port
            # 5354, never to libvirt's dnsmasq on 53: that one forwards to
            # this host's resolver, which is MagicDNS, so a guest could
            # resolve tailnet names. Every guest DNS query, whatever server
            # it names, is DNAT'd to 5354 (nat chain `vm-egress-dns`). The
            # port-53 drop in `mangle` INPUT stays as a backstop -- it's in
            # mangle because libvirt's iptables backend puts its own
            # DNS/DHCP ACCEPTs at the top of filter INPUT, ahead of
            # nixos-fw -- and DNAT has already rewritten the port by then.
            #
            # The per-interface options alone did NOT make that "exactly":
            # the host's global allowedTCPPorts/allowedUDPPorts (22, KDE
            # Connect, Steam, ... in system/networking) are rendered with
            # no `-i`, so they accepted on virbr0 too. The `cube-vm-in`
            # chain below closes that: jumped to FIRST in nixos-fw, it
            # refuses any new virbr0 connection outside the list and
            # RETURNs the rest to nixos-fw's normal accepts.
            networking.firewall = {
                interfaces."virbr0" = {
                    allowedUDPPorts = [ 67 5354 ];   # libvirt dnsmasq: DHCP; vm-egress-dns
                    allowedTCPPorts = [ 443 5354 ];  # Caddy; vm-egress-dns
                };

                # Guest -> LAN/tailnet, enforced on THIS side of the VM
                # boundary (a guest's own OUTPUT rules are flushable by guest
                # root). In `mangle` FORWARD, not `filter`: cube's libvirt
                # uses its iptables backend, which keeps its own jumps at the
                # top of filter FORWARD and ACCEPTs everything from the guest
                # subnet there -- a filter rule of ours would never be reached,
                # and libvirtd re-asserts that order on every restart. mangle
                # FORWARD runs before filter and libvirt doesn't touch it.
                # Replies (ESTABLISHED/RELATED) pass, so the sshForward DNAT's
                # return traffic to the tailnet still flows. Guest -> the
                # host's own addresses is INPUT, the chain above, not this.
                # Nothing here covers guest <-> guest on the same bridge (L2,
                # never routed).
                #
                # Past the private ranges, a new guest connection must go to
                # an address in the ipset `vm-egress-allow`, which only
                # vm-egress-dns.nix's resolver fills -- with the addresses it
                # just resolved for an allowlisted domain. So a guest reaches
                # allowlisted names and nothing else, including by raw IP.
                # actions-runner.nix's cycle empties the set before each job.
                # Addresses are shared by CDNs: allowing cache.nixos.org's
                # Fastly IPs allows whatever else Fastly serves on them.
                #
                # TRAP: cube-vm-in ends in a plain DROP, never
                # `-j nixos-fw-refuse`. It outlives nixos-fw across a firewall
                # restart, and firewall-start's teardown loop cannot `-X` a
                # chain something still jumps to -- that failure is swallowed,
                # and the `-N nixos-fw-refuse` after it then aborts the whole
                # start.
                extraCommands = ''
                    iptables -w -D nixos-fw -i virbr0 -j cube-vm-in 2>/dev/null || true
                    iptables -w -F cube-vm-in 2>/dev/null || true
                    iptables -w -X cube-vm-in 2>/dev/null || true
                    iptables -w -N cube-vm-in
                    iptables -w -A cube-vm-in -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
                    iptables -w -A cube-vm-in -p udp --dport 67 -j RETURN
                    iptables -w -A cube-vm-in -p tcp --dport 443 -d 192.168.122.1 -j RETURN
                    iptables -w -A cube-vm-in -p udp --dport 5354 -d 192.168.122.1 -j RETURN
                    iptables -w -A cube-vm-in -p tcp --dport 5354 -d 192.168.122.1 -j RETURN
                    iptables -w -A cube-vm-in -p icmp -j RETURN
                    iptables -w -A cube-vm-in -j DROP
                    iptables -w -I nixos-fw 1 -i virbr0 -j cube-vm-in

                    ip6tables -w -D nixos-fw -i virbr0 -m conntrack --ctstate NEW -j DROP 2>/dev/null || true
                    ip6tables -w -I nixos-fw 1 -i virbr0 -m conntrack --ctstate NEW -j DROP

                    iptables -w -t mangle -D FORWARD -i virbr0 -j cube-vm-egress 2>/dev/null || true
                    iptables -w -t mangle -F cube-vm-egress 2>/dev/null || true
                    iptables -w -t mangle -X cube-vm-egress 2>/dev/null || true
                    iptables -w -t mangle -N cube-vm-egress
                    iptables -w -t mangle -A cube-vm-egress -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
                    iptables -w -t mangle -A cube-vm-egress -d 10.0.0.0/8     -j DROP
                    iptables -w -t mangle -A cube-vm-egress -d 172.16.0.0/12  -j DROP
                    iptables -w -t mangle -A cube-vm-egress -d 192.168.0.0/16 -j DROP
                    iptables -w -t mangle -A cube-vm-egress -d 100.64.0.0/10  -j DROP
                    ipset -exist create vm-egress-allow hash:ip family inet
                    iptables -w -t mangle -A cube-vm-egress -m set ! --match-set vm-egress-allow dst -j DROP
                    iptables -w -t mangle -I FORWARD 1 -i virbr0 -j cube-vm-egress

                    iptables -w -t nat -D PREROUTING -i virbr0 -j vm-egress-dns 2>/dev/null || true
                    iptables -w -t nat -F vm-egress-dns 2>/dev/null || true
                    iptables -w -t nat -X vm-egress-dns 2>/dev/null || true
                    iptables -w -t nat -N vm-egress-dns
                    iptables -w -t nat -A vm-egress-dns -p udp --dport 53 -j DNAT --to-destination 192.168.122.1:5354
                    iptables -w -t nat -A vm-egress-dns -p tcp --dport 53 -j DNAT --to-destination 192.168.122.1:5354
                    iptables -w -t nat -I PREROUTING 1 -i virbr0 -j vm-egress-dns

                    iptables -w -t mangle -D INPUT -i virbr0 -p udp --dport 53 -j DROP 2>/dev/null || true
                    iptables -w -t mangle -D INPUT -i virbr0 -p tcp --dport 53 -j DROP 2>/dev/null || true
                    iptables -w -t mangle -I INPUT 1 -i virbr0 -p udp --dport 53 -j DROP
                    iptables -w -t mangle -I INPUT 1 -i virbr0 -p tcp --dport 53 -j DROP

                    ip6tables -w -t mangle -D FORWARD -i virbr0 -j DROP 2>/dev/null || true
                    ip6tables -w -t mangle -I FORWARD 1 -i virbr0 -j DROP
                '';
                # The firewall tears down nixos-fw (and so the jump into
                # cube-vm-in) itself; both chains are ours to remove, so
                # "firewall stopped" leaves nothing of this behind.
                extraStopCommands = ''
                    iptables -w -F cube-vm-in 2>/dev/null || true
                    iptables -w -X cube-vm-in 2>/dev/null || true
                    iptables -w -t mangle -D FORWARD -i virbr0 -j cube-vm-egress 2>/dev/null || true
                    iptables -w -t mangle -F cube-vm-egress 2>/dev/null || true
                    iptables -w -t mangle -X cube-vm-egress 2>/dev/null || true
                    ip6tables -w -t mangle -D FORWARD -i virbr0 -j DROP 2>/dev/null || true
                    iptables -w -t mangle -D INPUT -i virbr0 -p udp --dport 53 -j DROP 2>/dev/null || true
                    iptables -w -t mangle -D INPUT -i virbr0 -p tcp --dport 53 -j DROP 2>/dev/null || true
                    iptables -w -t nat -D PREROUTING -i virbr0 -j vm-egress-dns 2>/dev/null || true
                    iptables -w -t nat -F vm-egress-dns 2>/dev/null || true
                    iptables -w -t nat -X vm-egress-dns 2>/dev/null || true
                '';
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
            # virbr0 (and the guest-facing rules above) on every boot
            # regardless of whether anything ever uses it. A VM started by
            # hand instead -- outside that generator, e.g. via virt-manager
            # directly on durandal today -- still needs the old manual step:
            #
            #     virsh net-start default && virsh net-autostart default
            #
            # `virsh net-list --all` shows whether it took.
        };
}
