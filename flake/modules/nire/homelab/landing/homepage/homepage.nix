# homepage (gethomepage): the landing page for this host -- what's running,
# whether it's up, how the machine is doing, and the household calendar.
# Replaced glance here 2026-09-12 (issue #291); cube-only, same category
# (`nire/landing/`) -- the category-as-optionality mechanism CLAUDE.md's
# Architecture section gives `monitoring`, `git-forge`, `shortlinks` and
# `reverse-proxy`. The category kept the name `landing`; only the module
# underneath it changed.
#
# Named `homepage`, NOT `dashboard`. Not `landing` for the collision reason
# `git-forge` isn't `forgejo` (category + module sharing a name declare the
# same `flake.modules.nixos.<name>` and silently MERGE). Not `dashboard`
# because `monitoring` next door is full of Grafana dashboards; this is the
# page you LAND on, Grafana is where you read graphs.
#
# WHY HOMEPAGE OVER GLANCE: its calendar widget natively renders events
# from iCal feeds -- including gcal's SECRET iCal address, so no API key
# and no public-calendar compromise -- in a month grid AND an agenda view.
# glance's calendar is a bare date grid that takes no feed at all, which is
# what #208/#289/#290 (custom-api designs, a patched glance) existed to
# work around; all three closed as superseded when this landed.
#
# NOT a second monitoring system, same as glance before it: a service
# entry's `siteMonitor` is one HTTP HEAD per refresh reporting status and
# latency -- no scraping, storage, alerting, retention. prometheus.nix is
# what knows what CPU was an hour ago; this answers "is it up right now,
# and what's the URL", the question `wiki/homelab/README.md` answers for
# humans.
#
# EVERYTHING FETCHES SERVER-SIDE, which is the security shape of the whole
# page: `siteMonitor` pings, the calendar's iCal pulls and openmeteo's
# weather all run from this host (verified against homepage v1.13.2's
# source, matching the pinned package -- calendar/proxy.js, pages/api/
# siteMonitor.js). The browser never sees an ICS URL: the config files
# carry `{{HOMEPAGE_VAR_...}}` placeholders that homepage substitutes from
# its own environment (utils/config/config.js) AFTER reading them, and the
# calendar proxy strips the URL from anything it hands the client.
#
# SECRETS: the sops key `homepage-env` below IS a systemd EnvironmentFile
# -- plaintext lines of `HOMEPAGE_VAR_<NAME>=<value>`, one per calendar.
# gcal's secret iCal addresses go THERE, never in this file, the store, or
# the repo. systemd reads EnvironmentFile= itself as root before the
# DynamicUser drops privileges, so the secret's default 0400 root owner
# needs no override. Until real URLs are filled in, the ical integration
# fails QUIET (integrations/ical.jsx early-returns on fetch error, no
# error chip): the calendar renders as a bare grid + empty agenda, and
# events appear the moment the sops value gains real URLs and the secret's
# restartUnits bounces the service. Calendar IDs were deliberately not
# assigned at implementation (#289/#290's recorded decision) -- adding one
# is one entry in `calendars` below plus one line in the sops value.
#
# NO ICONS, DELIBERATELY -- now doubly so: every icon form homepage
# understands resolves via cdn.jsdelivr.net (resolvedicon.jsx: `mdi:`/
# `si:`/`sh:` prefixes AND the bare `name.png`/`.svg`/`.webp` fallback),
# and services with no `icon` set render none at all. A page whose point
# is not leaving the tailnet must not pull icons from a CDN on every load.
# If icons are ever wanted, homepage serves a local directory the same way
# glance's `assets-path` did -- upstream's `public/icons/` mechanism.
#
# ONLY CLICKABLE SERVICES ARE LISTED, carried over from glance: a
# loopback-only service (prometheus, node-exporter, cadvisor,
# libvirt-exporter) would render as a card whose link 404s in the reader's
# browser -- fine as a health check, misleading as a UI. Their health is
# in Grafana, which IS listed. Don't add them without a
# browser-followable URL. The siteMonitor checks go through the PROXY, at
# the URLs a person uses, not 127.0.0.1:300x -- same reasoning glance's
# monitor rows give (it tests MagicDNS, tailnet, caddy, TLS and app
# together, not the app alone).
#
# STATUS: config landed 2026-09-12; runtime verification pending the
# switch on cube (issue #291's acceptance list). Until then the live page
# is still glance.
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

        # The household's gcal calendars feeding the calendar widgets, as
        # integration name -> suffix of the HOMEPAGE_VAR_ env var holding
        # that calendar's SECRET iCal address. The addresses themselves
        # live only in the sops key `homepage-env` (declared below) --
        # never here. Adding a calendar: one entry here, one line
        # `HOMEPAGE_VAR_ICAL_<SUFFIX>=<secret-ics-url>` in the sops value.
        # Names show up as event prefixes only when an integration sets
        # `params.showName`, and distinguish the calendars' colors.
        calendars = {
            family = "ICAL_FAMILY";
        };

        calendarIntegrations = map
            (name: {
                type = "ical";
                inherit name;
                # Doubled braces are homepage's substitution syntax, not
                # Nix: the emitted YAML carries the literal
                # `{{HOMEPAGE_VAR_...}}` for homepage to replace at load.
                url  = "{{HOMEPAGE_VAR_${calendars.${name}}}}";
            })
            (builtins.attrNames calendars);
    in {
        flake.modules.nixos.${moduleName} = { config, ... }: {
            # # description = "homepage -- the landing page: what's running, whether it's up, the household calendar";

            # One sops key whose VALUE is a whole EnvironmentFile (see this
            # file's header: secret URLs stay out of the repo and the
            # store). sopsFile unset -- defaults to
            # `config.sops.defaultSopsFile` (secrets.yaml, set in
            # nire/system/secrets/sops.nix). Declared HERE and not in
            # sops.nix, on forgejo.nix's reasoning: `landing` is cube-only,
            # so the secret decrypts only where imported. restartUnits so
            # an edited calendar list reaches the running page without a
            # manual restart -- the same reassert-on-change shape
            # forgejo.nix's password reset takes.
            sops.secrets."homepage-env" = {
                restartUnits = [ "homepage-dashboard.service" ];
            };

            services.homepage-dashboard = {
                enable = true;

                # 3000 grafana, 3001 forgejo, 3002 here -- glance's old
                # slot, kept so nothing else about the port registry moves.
                # NOT the module's own default 8082: cadvisor already holds
                # 8080-adjacent ground and the 300x block is this host's
                # user-facing range (opencode-server-cube.nix took 3003 the
                # same way). One-switch overlap: the glance unit this
                # replaces bound the same port; activation stops removed
                # units before starting new ones, and homepage's
                # Restart=on-failure would self-heal the race regardless.
                listenPort = 3002;

                # LOOPBACK BIND IS THE SECURITY MODEL, as it was glance's --
                # but it does NOT come free here, and the difference is the
                # one thing to re-check on a package bump: glance had a
                # `host` option; this module exposes only `listenPort`
                # (PORT env), and `next start`'s own `--hostname` flag has
                # NO env binding in next 16 (bin/next.ts: `--port` carries
                # `.env('PORT')`, `--hostname` carries nothing) -- so the
                # service would bind 0.0.0.0 by default and, worse, the
                # firewall is not the backstop it looks like:
                # trustedInterfaces (system/networking/networking.nix)
                # lets tailnet traffic bypass the allow-list, so an
                # all-interfaces bind is directly reachable from the
                # tailnet, skipping caddy and its TLS entirely -- exactly
                # the shape grafana.nix and forgejo.nix were moved OFF in
                # 2026-08-24 (caddy.nix's header).
                #
                # The fix reads out of what the package actually runs:
                # nixpkgs' homepage-dashboard bin is `node .../server.js`,
                # the next STANDALONE template, whose bind line is
                # `process.env.HOSTNAME || '0.0.0.0'` (verified against
                # next 16.2.6, the version bundled with homepage-dashboard
                # 1.13.2 in this pin). Setting HOSTNAME in the unit
                # environment (below) is therefore a true loopback bind --
                # application-level, like glance's `host`, but reaching it
                # through systemd because no option path exposes it. If a
                # future next version changes that template line, the bind
                # silently WIDENS -- no error anywhere -- so `ss -ltn | grep
                # 3002` belongs in the post-bump checklist (wiki landing
                # page carries it).

                # Host-header EXACT match (src/middleware.js, v1.13.2):
                # every name that routes here must be listed, portless
                # because browsers omit :443. The localhost/127.0.0.1 forms
                # are auto-allowed by the middleware itself, keyed to
                # listenPort. A missing name is a middleware 403, not a
                # caddy error -- the failure mode if a future route move
                # forgets this line.
                allowedHosts = "${tailnetFqdn},${homepageFqdn}";

                # See the sops block above: systemd parses this file as
                # root pre-drop, so DynamicUser never needs to read it.
                environmentFiles = [
                    config.sops.secrets."homepage-env".path
                ];

                settings = {
                    # The one place the host's own name shows on the page,
                    # as glance's server-stats widget did.
                    title = "nire-cube";

                    # The `Calendar` service GROUP renders one column, so
                    # the two calendar cards get the group's full width
                    # instead of splitting a row -- the monthly grid is
                    # the widest thing on the page. Keys here are group
                    # names exactly as spelled in `services` below.
                    layout.Calendar = {
                        columns = 1;
                    };
                };

                # Info widgets, upstream's auto-grid across the top. The
                # two calendar views are NOT here -- see the closing
                # comment of this list for the calendar-widget trap and
                # the `Calendar` service group below for where they live.
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

                    # NOT here. THE CALENDAR WIDGET TRAP, found on the
                    # first live render (#291): `calendar` is NOT an info
                    # widget -- the info-widget registry
                    # (components/widgets/widget.jsx, v1.13.2) has no
                    # calendar entry, and a `calendar` line in widgets.yaml
                    # renders the literal fallback "Missing calendar", no
                    # error anywhere. Calendar views are SERVICE widgets
                    # (docs/widgets/services/calendar.md): declared under a
                    # service entry's `widget.` attrset, one entry per view
                    # -- see the `Calendar` group below.
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
                            {
                                # The calendars as SERVICE widgets -- see
                                # the widgets block above for why they are
                                # not in widgets.yaml. One entry per view
                                # (monthly grid, agenda list); there is no
                                # combined view. Each carries the same
                                # integrations -- two feed fetches, 5 min
                                # apart at most, for clean separation of
                                # the two views. The YAML key must be
                                # `integrations` (service-helpers.js reads
                                # exactly that off the widget);
                                # calendarIntegrations is only the Nix-
                                # side name. `timezone` pins "today" to
                                # the fleet's zone (tz.nix's
                                # `time.timeZone` default) rather than
                                # each viewer's browser. sunday first: en_US
                                # locale (locale.nix) -- glance defaulted
                                # monday "matching nothing in particular";
                                # here it is chosen, and change it here if
                                # that flips.
                                "Month grid" = {
                                    description = "the household calendars";
                                    widget = {
                                        type           = "calendar";
                                        view           = "monthly";
                                        firstDayInWeek = "sunday";
                                        showTime       = true;
                                        timezone       = "America/New_York";
                                        # The YAML key must be `integrations`
                                        # (service-helpers.js reads exactly
                                        # that off the widget);
                                        # calendarIntegrations is only the
                                        # Nix-side name.
                                        integrations = calendarIntegrations;
                                    };
                                };
                            }

                            {
                                # Second view = second entry; see the
                                # sibling above for the shared comments.
                                "Upcoming" = {
                                    description = "the same feeds, time-sorted";
                                    widget = {
                                        type     = "calendar";
                                        view     = "agenda";
                                        showTime = true;
                                        timezone = "America/New_York";
                                        integrations = calendarIntegrations;
                                    };
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
# 2026-08-24 to 2026-09-12 — glance (glanceapp/glance) was the landing
# page, module `landing/glance/glance.nix` (deleted here; `git log --follow`
# finds it). What this module inherited vs. dropped:
#
#   - INHERITED: the `landing` category and its naming reasoning; the port
#     (3002); loopback + no-firewall + no-persist shape; the
#     derive-from-caddy-vhosts throw-on-orphan mechanism (#221); the
#     no-CDN-icons rule; "only clickable services listed"; the
#     through-the-proxy monitoring URLs.
#   - DROPPED with glance, obsolete by construction: the four to-do lists
#     (#209). Homepage has no to-do widget, the lists were per-BROWSER
#     localStorage (per-device, not shared, lost on storage clear), and
#     #209's "categories" were distinguishable only by position. Decided
#     at implementation (#291 decision 2): drop, not replace. Anyone who
#     kept real tasks there will find them gone with the glance data.
#   - DROPPED: glance's own traps -- the monitor row that depended on Go's
#     redirect-following (homepage's siteMonitor follows redirects
#     explicitly, utils/proxy/http.js uses follow-redirects, so Grafana's
#     302 -> /login reads 200), and the `/api/pages/.../content/`
#     endpoint trick for verifying widget content (homepage is a
#     client-side app; what to check instead is on the wiki landing page).
#
# ROLLOUT, the half that is not in this repo (the caddy.nix svc:glance
# lesson: the record must not get ahead of reality):
#
#     just switch                                  # on cube
#     just tailscale-acl diff acl-diff-applied.hujson
#     just tailscale-acl apply acl-diff-applied.hujson   # svc:homepage in, svc:glance out
#     just tailscale-acl vip-put svc:homepage svc-homepage.json
#     just tailscale-acl vip-delete svc:glance
#
# `homepage.moose-micro.ts.net` does not resolve until the vip-put, and if
# the name still fails after it, the caddy.nix header has the restart
# order (tailscaled, then tailscale-serve) that woke svc:glance up. Then
# the verification ladder in the new-homelab-service skill, and `go/dash`
# (a golink DB row, outside this repo) repointed at whichever URL should
# be shortlinked.
