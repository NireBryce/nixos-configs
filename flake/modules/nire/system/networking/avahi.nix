{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "mDNS, so hosts resolve each other as <name>.local on the LAN";

            # Runs alongside services.resolved, which is enabled next door in
            # resolved.nix. They divide cleanly: avahi owns `.local`, resolved owns
            # unicast DNS and tailscale's split-DNS. The one thing that would make
            # them fight is both binding UDP 5353, and resolved.nix is where that
            # is settled -- see the MulticastDNS note there before changing either.
            services.avahi = {
                enable = true;

                # This is the half that makes nsswitch route `.local` here rather
                # than to resolved. nixpkgs wires the ordering deliberately: the
                # avahi module inserts `mdns4_minimal [NOTFOUND=return]` with
                # lib.mkBefore, commented "# before resolve", and the resolved
                # module inserts `resolve [!UNAVAIL=return]` at mkOrder 501 with a
                # comment saying 501 exists precisely so modules can go before it.
                # So a .local lookup stops at avahi and everything else falls
                # through. Nothing here has to arrange that.
                #
                # nssmdns6 is deliberately left off. It adds an AAAA path over
                # mDNS that nothing on this LAN answers, and the only effect would
                # be a lookup that waits before failing over. Turn it on with IPv6
                # mDNS, not before.
                nssmdns4 = true;

                # Both of these default to FALSE, and without them this host
                # resolves other machines' .local names while never answering for
                # its own -- which is the half that actually matters for reaching
                # a box by name. `publish-addresses` in avahi-daemon.conf is what
                # registers the A records for this host's addresses.
                publish = {
                    enable    = true;
                    addresses = true;
                };
            };

            # openFirewall is NOT set here: it already defaults to true and opens
            # UDP 5353 itself. Restating a default reads as a decision.

            # No avahi-persist.nix companion, deliberately, and the same goes for
            # resolved. Checked rather than assumed, because durandal, tenacity
            # and lego wipe the whole root subvolume on boot and anything under
            # /var/lib is gone unless WARN-impermanence.nix names it -- that is
            # how /etc/hhd was lost for a while. Neither nixpkgs module declares a
            # StateDirectory or any /var/lib path: avahi rebuilds its record set
            # at start from networking.hostName, and resolved's cache lives in
            # memory and /run. Nothing to carry across a boot.
        };
}
