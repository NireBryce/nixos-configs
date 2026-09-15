{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "systemd-resolved for unicast DNS, and the line that keeps it off mDNS";

            services.resolved = {
                enable = true;

                # THE COUPLING TO avahi.nix. Do not drop this line while avahi is
                # enabled, and do not keep it if avahi is ever removed.
                #
                # resolved ships its own mDNS stack and it is on by default, so
                # with avahi also running both bind UDP 5353. Multicast can be
                # multiply-bound, but a unicast 5353 reply reaches only one
                # listener, so lookups go intermittent rather than failing
                # outright -- the worst shape to debug. avahi logs that it found
                # another mDNS stack. Upstream: systemd/systemd#5530.
                #
                # Global rather than per-link on purpose: systemd ANDs the two, so
                # mDNS is on for a link only if the global AND the per-link
                # setting are on. That makes this authoritative -- NetworkManager
                # sets `connection.mdns` per-link on its own, and that is the
                # usual way people end up in the 5353 fight without asking for it.
                # A global "no" cannot be overridden by it.
                #
                # `settings`, not `extraConfig`: the latter is REMOVED in this
                # nixpkgs and throws on eval, so most guides and forum answers
                # about this setting no longer apply verbatim.
                settings.Resolve.MulticastDNS = "no";
            };

            # What this buys tailscale, which is half the reason it is here.
            #
            # tailscaled picks a DNS backend from what it finds. With no resolver
            # daemon it lands in "direct" mode: it rewrites /etc/resolv.conf and
            # then watches for other things trampling the file -- tailscale's own
            # docs describe dhclient and tailscaled "fighting with each other"
            # over it. With resolved present it uses the D-Bus path instead and
            # configures only its own link, passing the tailscale0 interface index
            # to SetLinkDNS / SetLinkDomains / SetLinkDefaultRoute. Nothing shared
            # gets rewritten, so there is nothing to clobber.
            #
            # It also sets SetLinkMulticastDNS(tailscale0, "no") itself -- "we
            # don't do multicast", in its own words -- so the MulticastDNS line
            # above agrees with what tailscale already wants rather than fighting
            # it.
            #
            # Two things nixpkgs' resolved module does that this file therefore
            # does NOT restate: it sets networking.networkmanager.dns =
            # "systemd-resolved", and it points /etc/resolv.conf at
            # /run/systemd/resolve/stub-resolv.conf. That symlink is exactly what
            # tailscale's Linux DNS docs tell you to arrange by hand.
            #
            # DNS servers themselves still come from the router over DHCP:
            # networking.nix's `networking.nameservers` is commented out (a58ad816),
            # so NetworkManager hands resolved whatever the LAN provides.
        };
}
