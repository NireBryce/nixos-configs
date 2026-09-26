{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # What libvirt guests (the Forgejo runner VM) may reach, by domain;
        # each entry covers its subdomains. Anything else gets NXDOMAIN
        # here, and a connection to an address this resolver didn't hand
        # out is dropped by vm-networking.nix's `cube-vm-egress`. Add a
        # domain here when a job needs one -- a failing job says so with a
        # name-resolution error.
        allowedDomains = [
            "nixos.org"               # cache.nixos.org, channels, releases, tarballs
            "forgejo.org"             # data/code.forgejo.org: `uses:` actions
            "github.com"              # github: flake inputs, codeload, api
            "githubusercontent.com"   # raw/objects: release assets, archives
            "pypi.org"                # PyPI index
            "pythonhosted.org"        # PyPI files
            "npmjs.org"               # npm registry
        ];
        upstreams = [ "9.9.9.9" "1.1.1.1" ];
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: let
            conf = pkgs.writeText "vm-egress-dns.conf" ''
                # 5354 on the bridge address; vm-networking.nix DNATs every
                # guest DNS query here. libvirt's own dnsmasq keeps :53.
                port=5354
                listen-address=192.168.122.1
                # virbr0 only exists once a VM has started the network.
                bind-dynamic
                no-resolv
                no-hosts
                no-poll
                pid-file=
                # No cache: dnsmasq adds to the ipset only when it forwards,
                # so a cached answer would hand out an address the firewall
                # then refuses (the cycle empties the set every job).
                cache-size=0
                # Everything not listed below: NXDOMAIN.
                address=/#/
                ${lib.concatMapStringsSep "\n" (d:
                    lib.concatMapStringsSep "\n" (u: "server=/${d}/${u}") upstreams
                ) allowedDomains}
                # The addresses of every answer for these names (CNAME chains
                # included -- the set is chosen by the question's name) go
                # into the set the firewall allows.
                ipset=/${lib.concatStringsSep "/" allowedDomains}/vm-egress-allow
            '';
        in {
            # # description = "allowlisting DNS for libvirt guests; fills the egress ipset";

            # The firewall script creates the set and matches on it
            # (vm-networking.nix); it needs the binary.
            networking.firewall.extraPackages = [ pkgs.ipset ];

            # Runs as root and drops to nobody, keeping CAP_NET_ADMIN for the
            # ipset writes (dnsmasq.c keeps it whenever ipsets are
            # configured). After the firewall: the set must exist first.
            systemd.services.vm-egress-dns = {
                description = "Allowlisting DNS resolver for libvirt guests";
                after    = [ "network.target" "firewall.service" ];
                wants    = [ "firewall.service" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    ExecStart  = "${pkgs.dnsmasq}/bin/dnsmasq --keep-in-foreground --log-facility=- --conf-file=${conf}";
                    Restart    = "always";
                    RestartSec = 5;
                };
            };
        };
}
