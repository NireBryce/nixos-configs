# services.tailscale.serve: raw TCP forwarding ONLY, from each Tailscale
# Service's own virtual address to Caddy's existing loopback listener.
# Grafana and Forgejo get their own tailnet DNS names (`svc:grafana`,
# `svc:git`) instead of a Caddy path prefix under
# ts-cube.moose-micro.ts.net -- but Caddy is still what terminates TLS,
# same as it always has for ts-cube itself, just for two more names now.
#
# THIS IS NOT THE ORIGINAL DESIGN, and the difference is load-bearing --
# see history below for what was tried first and why it didn't work.
# `endpoints."tcp:443"` here uses the `tcp://` backend scheme (raw byte
# forwarding, no HTTP interpretation at all), pointed at Caddy's own
# loopback address -- NOT `http://127.0.0.1:PORT` pointed directly at
# Grafana/Forgejo. tailscaled forwards the untouched TLS bytes (SNI
# ClientHello included) to Caddy; Caddy picks the right vhost by SNI, the
# same mechanism it already uses to be the ONE thing on this host that can
# bind 443 across every incoming name. See caddy.nix's new
# grafana./git.moose-micro.ts.net vhosts for the other half.
#
# UPSTREAM MODULE, NOT HAND-ROLLED: nixos/modules/services/networking/
# tailscale-serve.nix (pinned nixpkgs). Renders `services` below to a JSON
# file (svc:-prefixed automatically, do not add the prefix yourselves) and
# runs `tailscale serve set-config --all <file>` as a oneshot ordered
# after tailscaled.
#
# WHAT THIS REPLACES: caddy.nix's original `@grafana`/`handle_path
# /git/*` path-prefix routes (retired in caddy.nix's own history
# section), and the serve_from_sub_path/ROOT_URL path-prefix settings in
# grafana.nix/forgejo.nix -- both now point at their own service hostname
# instead of a path under ts-cube's.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.tailscale.serve = {
                enable = true;

                services = {
                    # Key becomes svc:grafana/svc:git/svc:glance -- the
                    # module adds the prefix, see its own option doc.
                    # `tcp://` value scheme, NOT `http://` -- see this
                    # file's header and history for why the obvious-looking
                    # form doesn't work. Target is Caddy's own loopback
                    # listener, not Grafana/Forgejo/Glance directly.
                    grafana.endpoints."tcp:443" = "tcp://127.0.0.1:443";
                    git.endpoints."tcp:443"     = "tcp://127.0.0.1:443";

                    # Added 2026-09-08: glance had no Tailscale Service of
                    # its own -- caddy.nix's `http://glance` bare-name
                    # redirect (added same day, f478494a) pointed at
                    # `ts-cube.moose-micro.ts.net` instead, which worked for
                    # THAT redirect but left `glance` itself unresolvable
                    # (no DNS record existed for the bare name at all --
                    # confirmed with `getent hosts glance` failing outright,
                    # distinct from the git/grafana SSL-alert bug below).
                    # This gives it the same real MagicDNS name as its two
                    # neighbours; caddy.nix's `glanceFqdn` vhost is the
                    # other half.
                    glance.endpoints."tcp:443"  = "tcp://127.0.0.1:443";
                };
            };

            # Added 2026-09-11 (issue #267): the upstream unit
            # (nixos/modules/services/networking/tailscale-serve.nix) has
            # no readiness gate on tailscaled's *backend* state, only an
            # `After=`/`Wants=` on the daemon *process*. On a real boot the
            # daemon can be up but still report `NoState` -- `serve
            # set-config` then fails outright ("unexpected state:
            # NoState"), and because the unit is `Type=oneshot` with no
            # `Restart=`, that single early failure is terminal: it stays
            # `failed` (no svc: forwards at all) until something else
            # happens to re-run it, e.g. the next `just switch`. Confirmed
            # live on nire-cube 2026-09-10, stayed failed 9.5 hours.
            #
            # `Restart=on-failure` IS legal on `Type=oneshot` (only
            # `always`/`on-success` are rejected -- checked against `man 5
            # systemd.service`), and a clean exit stops the restarts, so
            # this self-heals on the next race without looping once
            # tailscaled reaches `Running`. `StartLimitIntervalSec`/
            # `StartLimitBurst` bound it so a *persistent* failure (e.g.
            # tailscaled itself broken) still gives up instead of retrying
            # forever.
            #
            # Retry only, not a readiness-poll `ExecStartPre` -- smaller,
            # and self-heals the actual observed failure (a transient race)
            # rather than replacing `After=` with a hand-rolled wait loop.
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
# 2026-09-07 — first attempt: `endpoints."tcp:443" = "http://127.0.0.1:PORT"`,
# pointed directly at Grafana/Forgejo, no Caddy involved. This is the
# form the upstream NixOS module's own option doc's example uses, and
# what the design assumed would get free HTTPS from tailscaled the same
# way caddy.nix's `isTailscaleDomain` mechanism does for ts-cube.
#
# It did not: `tailscale serve status` showed
# `http://grafana.moose-micro.ts.net:443`, plain HTTP, confirmed by a raw
# (non-TLS) HTTP request actually reaching Grafana correctly (a real
# `302 -> /login`) while a TLS handshake against the same address:port
# failed outright ("wrong version number" -- nothing speaking TLS there
# at all). Tried the CLI directly too
# (`tailscale serve --service=svc:grafana --bg --https=443
# http://127.0.0.1:3000`, run with sudo on cube, not reachable from a
# non-interactive session) -- `tailscale serve status` still showed
# `http://`, no change.
#
# Root cause, confirmed against tailscale/tailscale's own issue tracker,
# not guessed: **tailscale/tailscale#18381** (open as of 2026-09-07) --
# `serve set-config`/`get-config`, the exact JSON-file mechanism this
# NixOS module uses, always round-trips a service's endpoint as
# `"tcp:443": "http://..."`, discarding HTTPS status regardless of what
# was actually configured. **#18219** (closed as a duplicate of the
# above) confirms the raw CLI *can* set real HTTPS
# (`tailscale serve --service=X --https=443 target` produces
# `"HTTPS": true`) but that state doesn't survive being read back through
# `get-config`/written through `set-config`, and per the reporter doesn't
# reliably survive a reboot either -- useless for a declarative Nix
# config either way. The proposed fix, **PR #20116**, was still an
# unmerged draft as of this check, nowhere near the pinned tailscale
# (1.102.2).
#
# THE RULE THIS GIVES: Tailscale Services cannot terminate HTTPS
# declaratively today (2026-09), on this tailscale version, via the
# config-file mechanism nixpkgs' `services.tailscale.serve` module is
# built on. Anything needing real HTTPS on a `svc:` name needs its own
# TLS terminator behind a `tcp://` raw forward, same as this file now
# does -- not the endpoint's `http://`/`https://` schemes, which only
# describe HOW TAILSCALED TALKS TO ITS OWN BACKEND when it (not always
# successfully) tries to terminate TLS itself.
