# Tailscale, as an actual service rather than just the CLI on PATH.
# Imported by every Linux host via the `system` category.
#
# FOUR REAL TRAPS, none of them a bug in this file or in
# resolved.nix/avahi.nix, and this header is where they live: wiki's
# categories/system.md, traps-and-skills.md and name-resolution.md all point
# HERE for the mechanism rather than restating it. Keep it that way -- if a
# trap ever moves to the wiki, those pointers move with it.
#
# 1. TAILNET DEVICE NAMES DO NOT MATCH `networking.hostName`. The NixOS host
#    is `nire-cube`, its Tailscale device and MagicDNS name is `ts-cube` --
#    fleet-wide (`ts-durandal`, `ts-lysithea`, `ts-tenacity`, ...).
#    `nire-cube.<tailnet>.ts.net` never resolves; it is not a name that
#    exists. Expensive to rediscover because it looks exactly like a DNS
#    failure (NXDOMAIN-shaped) until you check `tailscale status`.
#
# 2. PEER TRAFFIC TIMING OUT WHILE `tailscale ping` WORKS IS AN ACL PROBLEM,
#    not a host firewall problem. Control-plane traffic through and
#    peer-to-peer app traffic dropped (not refused) is the signature. This
#    repo's `trustedInterfaces = [ "tailscale0" ]` (networking.nix) is
#    provably not the cause -- it is a per-host NixOS setting, while the ACL
#    lives in Tailscale's admin console, outside this repo. The real fault,
#    2026-08-22: the tailnet's "match everything" rule had
#    `"dst": ["autogroup:internet"]` where it needed
#    `["autogroup:members"]`. `autogroup:internet` grants internet THROUGH an
#    exit node and nothing between members, despite the rule's own comment
#    reading "Match absolutely everything", so every peer connection was
#    denied at the mesh layer before reaching any host firewall.
#
# 3. A NAME THAT FLAT-OUT WILL NOT RESOLVE means check whether Tailscale is
#    up ON THE MACHINE YOU ARE RUNNING FROM -- distinct from trap 1, where
#    the wrong name resolves to nothing. Hit 2026-08-30 from lysithea, where
#    several turns went into diagnosing cube's health before trying
#    `nire-cube.local`, plain LAN mDNS via avahi.nix, which needs no
#    Tailscale and had been reachable the whole time. `just reach <host>`
#    (flake/scripts/reach-host.sh) tries all of a host's real names so this
#    does not get re-derived by hand.
#
# 4. TAGGING A DEVICE DROPS IT OUT OF `autogroup:members` as a grant
#    DESTINATION, because a tagged device is owned by the tag rather than
#    the user. Applying tag:homelab-cube on 2026-09-07 made nire-cube vanish
#    from every other peer's `tailscale status` within a minute -- absent,
#    not offline, SSH included -- while cube's own status looked normal
#    throughout. THE RULE: tagging a previously-untagged device and adding
#    its compensating grant (`{"src": ["autogroup:members"], "dst":
#    ["tag:whatever"], "ip": ["*"]}`) are ONE atomic change, never staged.
#    Its source-side twin -- a tagged host receiving no `svc:` DNS records
#    for what it advertises, issue #298 -- is in
#    homelab/reverse-proxy/tailscale-services/README.md with both fixes.
#
# DIAGNOSTIC WORTH KEEPING, no root needed: `openFirewall` and
# `trustedInterfaces` compile down to a plain shell script
# (`systemctl show firewall.service -p ExecStart`, then read that store
# path) holding the literal, in-order `iptables` commands applied at boot,
# world-readable. Settles "is trustedInterfaces really first" without
# querying the live table.
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

# ── history ─────────────────────────────────────────────────────────────────
#
# Added because `tailscale` sat in vpn.nix's environment.systemPackages under
# a `# TODO: move to module`: the binary existed and nothing ran it
# (`systemctl is-enabled tailscaled` answered "not-found" -- no unit at all).
# `services.tailscale.enable` generates the unit AND installs the CLI itself,
# so vpn.nix's copy was dropped rather than left to shadow this one.
# networking.nix's two `# TODO: move to tailscale-autoconnect` markers went
# the same way: upstream `openFirewall` opens the daemon's UDP port and an
# autoconnect unit comes free with `authKeyFile` -- check upstream before
# hand-writing a shim, the same lesson handheld-daemon taught.
#
# 2026-08-22 — split-DNS (resolved.nix/avahi.nix) runtime-verified on
# nire-tenacity, upgrading those files from the evaluation-only status they
# were added under the day before: `getent hosts`, `ping` and `ssh` all
# resolved peers by MagicDNS name through nsswitch -> resolve ->
# systemd-resolved -> tailscale0's D-Bus split-DNS. That mechanism was never
# the problem -- traps 1 and 2 above were.
