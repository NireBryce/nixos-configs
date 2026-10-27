# libvirt's default network, written in one place. A plain attrset `import`ed by path,
# filed under `_lib/` because import-tree ignores any path containing `/_`
# (same reason as virtualization/VMs/_lib/libvirt-vm.nix).
#
# The bridge address is libvirt's own default, not something this repo
# configures, so every consumer below is the firewall, Caddy or a guest
# agreeing with libvirt. A change here has to follow libvirt's network, and
# all of them move together:
#   - vm-networking.nix: the guest-facing firewall rules (gateway)
#   - vm-egress-dns.nix: the resolver's listen address (gateway)
#   - caddy.nix: `vmDeny` / `vmRunnerPathsOnly` match guests by cidr
#   - libvirt-vm.nix: a guest's DHCP-reserved address (prefix)
#   - actions-runner.nix: `ssh forge-runner` (prefix)
rec {
    prefix  = "192.168.122";
    gateway = "${prefix}.1";
    cidr    = "${prefix}.0/24";
}
