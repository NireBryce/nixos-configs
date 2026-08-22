# Tailscale, as an actual service rather than just the CLI on PATH.
#
# vpn.nix had `tailscale` in environment.systemPackages with `# TODO: move to
# module` next to it, and that was the whole of it: the binary existed, nothing
# ran it. `systemctl is-enabled tailscaled` answered "not-found" -- no unit, not
# a stopped one. services.tailscale.enable is what actually generates it, and it
# installs the CLI itself (`environment.systemPackages = [ cfg.package ]`, in
# nixos/modules/services/networking/tailscale.nix), so vpn.nix's copy was dropped
# in the same change rather than left to shadow this one.
#
# networking.nix carried two `# TODO: move to tailscale-autoconnect` markers, for
# a module that was never written. Upstream now covers what they were reaching
# for: `openFirewall` opens the daemon's UDP port (the commented-out
# `config.services.tailscale.port` line there), and an autoconnect unit comes
# free with `authKeyFile` if it is ever wanted. Same shape as the
# handheld-daemon shim that turned out to be unnecessary -- check upstream before
# hand-writing the integration.
#
# DNS split-DNS (resolved.nix/avahi.nix) RUNTIME-VERIFIED, 2026-08-22, on
# nire-tenacity -- upgraded from the "evaluation only" status resolved.nix and
# avahi.nix were added under (2026-08-21). `getent hosts`, `ping`, and `ssh`
# all correctly resolved peers by their MagicDNS name via
# nsswitch -> resolve -> systemd-resolved -> tailscale0's D-Bus split-DNS.
# Nothing about that mechanism was the problem the one time it looked broken
# (below) -- it wasn't DNS at all.
#
# TWO REAL TRAPS FOUND DIAGNOSING "nire-cube unreachable from nire-tenacity"
# THAT DAY, neither of them a bug in this file or in resolved.nix/avahi.nix:
#
# 1. This tailnet's device names do NOT match `networking.hostName`. The
#    NixOS host is `nire-cube`; its Tailscale device (and therefore its
#    MagicDNS name) is `ts-cube`. Same pattern fleet-wide -- `ts-durandal`,
#    `ts-lysithea`, `ts-tenacity`, etc. `nire-cube.<tailnet>.ts.net` was never
#    going to resolve; it isn't a name that exists. Costly to rediscover: it
#    looks exactly like a DNS failure (NXDOMAIN-shaped) right up until you
#    check `tailscale status` for the name it actually registered.
#
# 2. Even with the right name, connections (ssh, ping) timed out -- not
#    refused, silently dropped -- despite `tailscale ping` succeeding (a
#    direct LAN connection) and tailscaled's own PeerAPI port answering.
#    That asymmetry -- tailscale's own control-plane traffic gets through,
#    ordinary app traffic between peers doesn't -- is the signature of a
#    TAILNET ACL PROBLEM, not a host firewall problem: this repo's
#    `networking.firewall.trustedInterfaces = [ "tailscale0" ]` (networking.nix)
#    is provably not the cause, since it's a per-host NixOS setting and the
#    ACL lives in Tailscale's admin console, entirely outside this repo. The
#    actual fault: the tailnet's "match everything" access rule had
#    `"dst": ["autogroup:internet"]` instead of `["autogroup:members"]`.
#    `autogroup:internet` only grants access to the internet *through* an
#    exit node -- it grants nothing between ordinary tailnet members, despite
#    a rule comment literally saying "Match absolutely everything." No rule
#    in the policy covered member-to-member traffic at all, so every peer
#    connection was silently denied at the mesh layer, before ever reaching a
#    host's own OS firewall. Fixed by changing that rule's `dst` to
#    `autogroup:members` in the admin console -- nothing to change here.
#
# Diagnostic trick worth keeping: to check whether a *local* NixOS firewall
# rule is really the problem, you don't need root. `services.tailscale.openFirewall`
# and `networking.firewall.trustedInterfaces` both compile down to a plain
# shell script (`systemctl show firewall.service -p ExecStart`, then read
# that store path) containing the literal, in-order `iptables` commands
# applied at boot -- world-readable, and it settles rule-ordering questions
# (e.g. "is trustedInterfaces really first in the chain") without querying
# the live table at all.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.tailscale = {
                enable = true;

                # Opens the daemon's own UDP port. networking.nix already has
                # `tailscale0` in trustedInterfaces, which is the other half --
                # that covers traffic arriving over the tunnel, this covers the
                # tunnel being established.
                openFirewall = true;

                # authKeyFile is deliberately NOT set, though secrets.yaml does
                # carry an (undeclared, unused) `tailscale_key`. Tailscale auth
                # keys expire -- 90 days maximum, and that one predates the
                # flake-parts port -- so wiring it in would most likely mean a
                # tailscaled-autoconnect.service that fails on every boot rather
                # than a machine that authenticates itself. With the state
                # directory persisted by tailscale-persist.nix, `sudo tailscale
                # up` once is enough and survives reboots. To revisit: mint a
                # fresh key, add `sops.secrets.tailscale_key` in
                # system/secrets/sops.nix (nothing declares it today), and point
                # authKeyFile at config.sops.secrets.tailscale_key.path.
            };
        };
}
