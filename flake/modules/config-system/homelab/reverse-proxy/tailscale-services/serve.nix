# services.tailscale.serve: raw TCP forwarding ONLY, from each Tailscale
# Service's virtual address to caddy's existing loopback listener, so each
# app gets its own tailnet DNS name instead of a path prefix under
# ts-cube.moose-micro.ts.net. Caddy still terminates TLS -- caddy.nix's
# `.ts.net` vhosts are the other half. Added 2026-09-07.
#
# Kept elsewhere, not restated here: the design and the current names,
# wiki/categories/reverse-proxy.md and its `-for-agents.md`; the first
# attempt and why it failed, `reverse-proxy-history.md`; the control-plane
# half (Service objects, ACL entries, `vip-put` traps, what is applied
# live), this directory's README.md. Traps sit next to the options.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.tailscale.serve = {
                enable = true;

                # Upstream module, not hand-rolled
                # (nixos/modules/services/networking/tailscale-serve.nix):
                # renders this to JSON and runs `tailscale serve set-config
                # --all` as a oneshot after tailscaled. Each key becomes
                # `svc:<key>` -- the module adds the prefix, don't.
                services = {
                    # `tcp://`, NOT `http://`: raw byte forwarding with no
                    # HTTP interpretation, aimed at caddy's own 443, not at
                    # the app's port. tailscaled hands the untouched TLS
                    # bytes (SNI ClientHello included) to caddy, which picks
                    # the vhost by SNI. The obvious `http://127.0.0.1:PORT`
                    # form -- what the upstream option doc's example uses --
                    # cannot give these names HTTPS at all; see history.
                    grafana.endpoints."tcp:443" = "tcp://127.0.0.1:443";
                    git.endpoints."tcp:443"     = "tcp://127.0.0.1:443";

                    # PORT 80 IS NOT DECORATION. A `svc:` name resolves to a
                    # Service VIP, which answers only on ports declared in
                    # BOTH this endpoint set and the Service object's own
                    # `ports` list (svc-*.json, re-`vip-put` after editing).
                    # Declaring 443 alone left caddy.nix's `http://git` etc.
                    # bare-name redirects unreachable from the day they were
                    # written until 2026-09-11 (issue #272) -- and those are
                    # the doors worth keeping, being the ones with no
                    # certificate in the path and so no local-CA warning.
                    # `http://ts-cube` worked throughout, being a device
                    # address where caddy binds 80 directly, which is what
                    # made the gap easy to miss.
                    grafana.endpoints."tcp:80"  = "tcp://127.0.0.1:80";
                    git.endpoints."tcp:80"      = "tcp://127.0.0.1:80";

                    # A RENAME HERE IS A NEW SERVICE to tailscaled -- the
                    # serve config drops one advertisement and adds another,
                    # and the control-plane object has to be re-made to
                    # match (`vip-put`/`vip-delete`, README.md). Renamed
                    # from `glance` 2026-09-12 with the landing page (issue
                    # #291); homepage.nix's history has the rollout order.
                    homepage.endpoints."tcp:443" = "tcp://127.0.0.1:443";
                    homepage.endpoints."tcp:80"  = "tcp://127.0.0.1:80";

                    # Back with glance itself 2026-09-13 for the landing
                    # evaluation. Which port sits behind caddy for a given
                    # name is caddy.nix's business, not this file's -- every
                    # endpoint here forwards to the same two caddy ports.
                    glance.endpoints."tcp:443" = "tcp://127.0.0.1:443";
                    glance.endpoints."tcp:80"  = "tcp://127.0.0.1:80";
                };
            };

            # Added 2026-09-11 (issue #267). The upstream unit gates on
            # tailscaled the PROCESS, not on its backend state, so on a real
            # boot `serve set-config` can hit a daemon reporting `NoState`
            # and fail outright -- and `Type=oneshot` with no `Restart=`
            # makes that terminal: no svc: forwards at all until something
            # re-runs the unit. Confirmed live on cube 2026-09-10, failed
            # for 9.5 hours.
            #
            # `Restart=on-failure` IS legal on `Type=oneshot` (only
            # `always`/`on-success` are rejected -- checked against `man 5
            # systemd.service`), and a clean exit ends the retries, so this
            # self-heals the race without looping. The StartLimit pair
            # bounds it, so a persistent failure still gives up. Retry
            # rather than a readiness-polling `ExecStartPre`: smaller, and
            # it fixes the failure actually observed.
            systemd.services.tailscale-serve = {
                serviceConfig = {
                    Restart              = "on-failure";
                    RestartSec           = 5;
                    StartLimitIntervalSec = 60;
                    StartLimitBurst      = 6;
                };
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-09-07 — the first attempt pointed `endpoints."tcp:443"` straight at
# Grafana/Forgejo as `http://127.0.0.1:PORT`, expecting tailscaled to
# terminate HTTPS the way it does for a device's own MagicDNS name. It
# cannot: `serve set-config`/`get-config`, the exact mechanism nixpkgs'
# module is built on, round-trips every endpoint back to plain HTTP
# (tailscale/tailscale#18381, open; #18219 confirms the raw CLI can set real
# HTTPS but that it doesn't survive set-config or a reboot; the fix, PR
# #20116, was an unmerged draft against a tailscale newer than the pinned
# 1.102.2). Symptoms, the CLI attempt, and the exact failing commands:
# wiki/categories/reverse-proxy-history.md.
#
# THE RULE THAT GIVES, still live: a `svc:` name needing real HTTPS needs
# its own TLS terminator behind a `tcp://` raw forward, as here. An
# endpoint's `http://`/`https://` scheme only describes how tailscaled
# talks to its own backend when it tries to terminate TLS itself.
