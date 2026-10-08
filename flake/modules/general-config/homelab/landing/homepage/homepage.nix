# homepage (gethomepage): the landing page for this host -- what's running,
# whether it's up, how the machine is doing. The household calendar views
# came off 2026-10-06 (#299 closed removed-not-filled); see the comment at
# the former `calendars` attrset below. Replaced glance here 2026-09-12
# (issue #291), cube-only; glance rejoined 2026-09-13 at its own name for
# the evaluation, so the category has two modules until that closes.
#
# Named `homepage`, NOT `landing` (a category and its module sharing a name
# declare the same `flake.modules.nixos.<name>` and silently MERGE) and NOT
# `dashboard` (`monitoring` next door is full of Grafana dashboards; this is
# the page you LAND on).
#
# Kept in the wiki, not restated here: why homepage over glance, what this
# deliberately is not, the widget inventory, the icon and clickable-service
# rules, and the verification record -- wiki/categories/landing.md and its
# `-for-agents.md`. Usage and URLs: wiki/homelab/reaching-services.md.
# Traps sit next to the options.
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

    # The two names the page answers on. Duplicated (by necessity --
    # nothing declares options, CLAUDE.md Architecture) from caddy.nix,
    # which holds the same strings for the same reason: the ts-cube
    # device name, and homepage's own Tailscale Service name, the
    # #211/#220 pattern its three neighbours use. reached-as
    # `https://<name>/` and, for the svc: one, `http://homepage/`.
    tailnetFqdn  = "ts-cube.moose-micro.ts.net";
    homepageFqdn = "homepage.moose-micro.ts.net";

    # The service cards for services THIS host proxies, derived from
    # caddy's own vhost table -- carried over verbatim in mechanism
    # from glance.nix (issue #221): the attribute names of
    # `services.caddy.virtualHosts` ARE the public site addresses
    # (caddy.nix), so a rename there flows into these URLs instead of
    # leaving a stale, silently-wrong card behind. Keyed by a substring
    # unique to the wanted vhost (the FQDN form, not the bare
    # `http://<name>` redirect vhosts -- those keys contain no dot); a
    # label matching nothing is an EVAL ERROR, not an empty card, so
    # removing a service forces an edit here in the same change. The
    # one hand-written card is golink, which is not this host's vhost
    # at all (own tailnet device, golink.nix).
    proxied = {
        grafana = "Grafana";
        git     = "Forgejo";
    };

    proxiedSite = vhosts: label: title:
    let
        matches = builtins.filter
            (v: lib.hasInfix label v && lib.hasInfix "." v)
            vhosts;
    in
        if matches == []
        then builtins.throw "homepage services: no caddy vhost matches '${label}' -- the service moved or was renamed; update homepage.nix's `proxied` in the same change (issue #221)"
        else {
            ${title} = {
                href = "https://${builtins.head matches}/";
                # Same URL as href: the card then shows live
                # status + latency, checked through the proxy.
                siteMonitor = "https://${builtins.head matches}/";
            };
        };

    # The household's gcal calendars fed two calendar views here until
    # 2026-10-06: the real secret iCal addresses never landed (#299 --
    # the 2026-09-29 sops fill still 403'd), and the placeholder fetch
    # kept hitting Google's server on every widget refresh. Removed
    # rather than left erroring; #230 holds the calendar direction.
    # Re-adding is the shape wiki/categories/landing.md's gcal section
    # documents -- names attrset, `{{HOMEPAGE_VAR_ICAL_*}}` service
    # widgets, one line in the sops value -- and its schema trap
    # (`calendar` is a service widget, not an info widget) still
    # applies. The `homepage-env` sops key stays in secrets.yaml,
    # unreferenced, on the syncthing-keys precedent.
in {
    flake.modules.nixos.${moduleName} = { config, ... }: {
        # # description = "homepage -- the landing page: what's running, whether it's up";

        services.homepage-dashboard = {
            enable = true;

            # 3000 grafana, 3001 forgejo, 3002 here -- glance's old
            # slot, kept so nothing else about the port registry moves.
            # NOT the module's own default 8082: cadvisor already holds
            # 8080-adjacent ground and the 300x block is this host's
            # user-facing range (opencode-server.nix took 3003 the
            # same way). One-switch overlap: the glance unit this
            # replaces bound the same port; activation stops removed
            # units before starting new ones, and homepage's
            # Restart=on-failure would self-heal the race regardless.
            listenPort = 3002;

            # LOOPBACK BIND DOES NOT COME FREE HERE, and this is the
            # one thing to re-check on a package bump. No option path
            # exposes a bind host (the module has `listenPort` only;
            # next 16's `--hostname` has no env binding), so the
            # service binds 0.0.0.0 by default -- and the firewall is
            # NOT the backstop it looks like, since trustedInterfaces
            # lets tailnet traffic bypass the allow-list and reach it
            # directly, skipping caddy and its TLS. What makes it
            # loopback is HOSTNAME in the unit environment below,
            # because next's standalone server.js binds
            # `process.env.HOSTNAME || '0.0.0.0'` (read from next
            # 16.2.6, bundled with homepage-dashboard 1.13.2 here). A
            # future next changing that line widens the bind SILENTLY,
            # no error anywhere -- hence `ss -ltn | grep 3002` in
            # landing.md's post-bump checklist.

            # Host-header EXACT match (src/middleware.js, v1.13.2):
            # every name that routes here must be listed, portless
            # because browsers omit :443. The localhost/127.0.0.1 forms
            # are auto-allowed by the middleware itself, keyed to
            # listenPort. A missing name is a middleware 403, not a
            # caddy error -- the failure mode if a future route move
            # forgets this line.
            allowedHosts = "${tailnetFqdn},${homepageFqdn}";

            settings = {
                # The one place the host's own name shows on the page,
                # as glance's server-stats widget did.
                title = "nire-cube";
            };

            # Info widgets, upstream's auto-grid across the top. The
            # two calendar views are NOT here -- removed 2026-10-06
            # (#299); see the closing comment of this list.
            widgets = [
                {
                    # Replaces glance's server-stats. The nixpkgs
                    # module sets `ProcSubset = "all"` on the unit ONLY
                    # when a `resources` widget declares `cpu = true`
                    # -- that is what makes the CPU line work under the
                    # DynamicUser sandbox; without it the widget
                    # renders empty, not an error (glance's
                    # server-stats carried the same trap).
                    resources = {
                        cpu    = true;
                        memory = true;
                        disk   = "/";
                        uptime = true;
                    };
                }

                {
                    # Replaces glance's weather widget (issue #226).
                    # Keyless, same upstream source (api.open-meteo.com;
                    # homepage's `weather` widget is the OTHER one,
                    # weatherapi.com, which needs an API key). An
                    # invalid location fails a fetch, not startup --
                    # but the coordinates are fixed points, not a
                    # geocoder guess. `cache` is MINUTES
                    # (cachedRequest, utils/proxy/http.js).
                    openmeteo = {
                        latitude  = "40.7128";
                        longitude = "-74.0060";
                        units     = "imperial";
                        timezone  = "America/New_York";
                        cache     = 15;
                    };
                }

                # No calendar entries since 2026-10-06 (#299). The
                # schema trap they were found on (#291) -- `calendar`
                # is a service widget, not an info widget; a `calendar`
                # line in widgets.yaml renders "Missing calendar" with
                # no error anywhere -- is landing.md's to carry if
                # they return.
            ];

            services = let
                vhosts = builtins.attrNames config.services.caddy.virtualHosts;
            in [
                {
                    Services = (map
                        (label: proxiedSite
                            vhosts
                            label
                            proxied.${label})
                        (builtins.attrNames proxied)) ++ [
                        {
                            # Its own tailnet device
                            # (shortlinks/golink.nix embeds tsnet),
                            # listed as a fleet service -- cube does
                            # not serve it. Same as glance's one
                            # hand-written monitor row.
                            golink = {
                                href        = "http://go/";
                                siteMonitor = "http://go/";
                            };
                        }
                    ];
                }
            ];
        };

        # No firewall entry and no homepage-persist.nix, for the
        # reasons the neighbouring modules give: the port is loopback
        # only (HOSTNAME above), so nothing arrives at the firewall;
        # cube has a plain persistent root (cube-configuration.nix's
        # header), so the module's StateDirectory/CacheDirectory
        # survive reboots. Nothing in them is worth keeping anyway --
        # the page renders from live state, config is from the store.

        # The loopback bind itself -- see the comment at
        # `services.homepage-dashboard` above for why this is an
        # environment variable rather than an option.
        systemd.services.homepage-dashboard.environment.HOSTNAME =
            "127.0.0.1";
    };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 to 2026-09-12 — glance was the landing page (issue #291
# replaced it; glance rejoined 2026-09-13 at its own name for the
# evaluation, so both are live). What carried over and what was dropped --
# including the four to-do lists (#209), obsolete by construction since
# homepage has no to-do widget and they were per-browser localStorage --
# is in wiki/categories/landing.md's "glance, retired 2026-09-12".
#
# ROLLOUT, the half that is NOT in this repo, kept here because the record
# must not get ahead of reality (the svc:glance lesson):
#
#     just switch                                  # on cube
#     just tailscale-acl diff acl-diff-applied.hujson
#     just tailscale-acl apply acl-diff-applied.hujson   # svc:homepage in, svc:glance out
#     just tailscale-acl vip-put svc:homepage svc-homepage.json
#     just tailscale-acl vip-delete svc:glance
#
# The name does not resolve until the vip-put; if it still fails after it,
# caddy.nix has the restart order (tailscaled, then tailscale-serve) that
# woke svc:glance. Then the new-homelab-service skill's verification
# ladder, and `go/dash` (a golink DB row, outside this repo) repointed.
#
# 2026-09-12, what the rollout did: switch -> ACL apply -> vip-put -> vip-
# delete -> one tailscaled+tailscale-serve restart (the standing-
# advertisement activation gap; tailscale-serve's Restart=on-failure from
# issue #267 absorbed the first racing attempt) -> verified. The one
# failure mode found was #298, not homepage's -- fixed 2026-09-14.
#
# 2026-10-06 -- the two calendar views came off the page (#299, closed
# removed-not-filled): the real secret iCal addresses never landed (the
# 2026-09-29 sops fill still 403'd) and the placeholder fetch kept hitting
# Google on every widget refresh. `calendars`/`calendarIntegrations`, the
# `layout.Calendar` group, both service-widget entries and the
# `homepage-env` sops declaration went with them; the sops key itself
# stays in secrets.yaml, unreferenced (the syncthing-keys precedent).
# Re-adding is landing.md's gcal section; #230 holds the direction.
