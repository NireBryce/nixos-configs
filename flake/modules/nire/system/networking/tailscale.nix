# Tailscale, as an actual service rather than just the CLI on PATH.
#
# vpn.nix had `tailscale` in environment.systemPackages with `# TODO: move to
# module` next to it: the binary existed, nothing ran it -- `systemctl
# is-enabled tailscaled` answered "not-found" (no unit, not a stopped one).
# services.tailscale.enable generates the unit and installs the CLI itself
# (`environment.systemPackages = [ cfg.package ]`,
# nixos/modules/services/networking/tailscale.nix), so vpn.nix's copy was
# dropped rather than left to shadow this one.
#
# networking.nix carried two `# TODO: move to tailscale-autoconnect` markers
# for a module never written. Upstream now covers both: `openFirewall` opens
# the daemon's UDP port; an autoconnect unit comes free with `authKeyFile`
# if ever wanted. Same shape as the handheld-daemon shim that turned out
# unnecessary -- check upstream before hand-writing.
#
# DNS split-DNS (resolved.nix/avahi.nix) RUNTIME-VERIFIED 2026-08-22 on
# nire-tenacity, upgraded from the "evaluation only" status those files were
# added under (2026-08-21): `getent hosts`, `ping`, and `ssh` all resolved
# peers by MagicDNS name via nsswitch -> resolve -> systemd-resolved ->
# tailscale0's D-Bus split-DNS. That mechanism was never the problem (below).
#
# TWO REAL TRAPS found diagnosing "nire-cube unreachable from nire-tenacity"
# that day, neither a bug in this file or in resolved.nix/avahi.nix:
#
# 1. Tailnet device names do NOT match `networking.hostName`: the NixOS host
#    is `nire-cube`, its Tailscale device (and MagicDNS name) is `ts-cube` --
#    fleet-wide (`ts-durandal`, `ts-lysithea`, `ts-tenacity`, ...).
#    `nire-cube.<tailnet>.ts.net` never resolves; it isn't a name that
#    exists. Costly to rediscover: it looks exactly like a DNS failure
#    (NXDOMAIN-shaped) until you check `tailscale status`.
#
# 2. Even with the right name, connections (ssh, ping) timed out -- dropped,
#    not refused -- while `tailscale ping` succeeded (direct LAN) and
#    tailscaled's PeerAPI port answered. That asymmetry -- control-plane
#    traffic through, peer-to-peer app traffic not -- is the signature of a
#    TAILNET ACL PROBLEM, not a host firewall problem: this repo's
#    `networking.firewall.trustedInterfaces = [ "tailscale0" ]`
#    (networking.nix) is provably not the cause (per-host NixOS setting;
#    the ACL lives in Tailscale's admin console, outside this repo). The
#    fault: the tailnet's "match everything" rule had
#    `"dst": ["autogroup:internet"]` instead of `["autogroup:members"]` --
#    `autogroup:internet` only grants internet *through* an exit node,
#    nothing between members, despite the rule comment saying "Match
#    absolutely everything." No rule covered member-to-member traffic, so
#    every peer connection was silently denied at the mesh layer, before any
#    host's own firewall. Fixed in the admin console -- nothing to change
#    here.
#
# Diagnostic trick worth keeping: to check whether a *local* NixOS firewall
# rule is really the problem, no root needed -- `openFirewall` and
# `trustedInterfaces` compile down to a plain shell script (`systemctl show
# firewall.service -p ExecStart`, then read that store path) holding the
# literal, in-order `iptables` commands applied at boot, world-readable;
# settles rule-ordering questions ("is trustedInterfaces really first")
# without querying the live table.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.tailscale = {
                enable = true;

                # Opens the daemon's own UDP port. networking.nix's
                # `tailscale0` in trustedInterfaces is the other half: that
                # covers traffic arriving over the tunnel, this the tunnel
                # being established.
                openFirewall = true;

                # authKeyFile deliberately NOT set, though secrets.yaml does
                # carry an (undeclared, unused) `tailscale_key`. Auth keys
                # expire -- 90 days maximum, and that one predates the
                # flake-parts port -- so wiring it in would most likely mean a
                # tailscaled-autoconnect.service failing on every boot rather
                # than a machine that authenticates itself. With the state
                # directory persisted by tailscale-persist.nix, `sudo
                # tailscale up` once is enough and survives reboots. To
                # revisit: mint a fresh key, add `sops.secrets.tailscale_key`
                # in system/secrets/sops.nix (nothing declares it today), and
                # point authKeyFile at config.sops.secrets.tailscale_key.path.
            };
        };
}
