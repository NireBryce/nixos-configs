# glance: the second landing page for this host, running beside homepage
# (which replaced it 2026-09-12, issue #291) since 2026-09-13 so both can
# be tried live before picking one. Cube-only. homepage keeps the ts-cube
# root and its own name; this answers at `glance.moose-micro.ts.net` ONLY
# (short `http://glance/`), serving at `/` of its own vhost, so `base-url`
# stays unset. An evaluation arrangement: the loser's module, vhosts and
# Service object delete cleanly.
#
# The CATEGORY is `landing`, not `glance` or `dashboard` -- a category and
# a module sharing a name declare the same `flake.modules.nixos.<name>` and
# silently MERGE, which is what lets this sit beside homepage.nix in one
# category without meeting it.
#
# Kept in the wiki, not restated here: what this deliberately is not, the
# icon and clickable-service rules, the widget inventory, and the
# verification record -- wiki/categories/landing.md and `-for-agents.md`.
# Usage and URLs: wiki/homelab/reaching-services.md. Traps sit next to the
# options.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # The monitor's rows for services THIS host proxies, derived from
        # caddy's own vhost table (issue #221): the attribute names of
        # `services.caddy.virtualHosts` ARE the public site addresses
        # (caddy.nix), so a rename there flows into these URLs instead of
        # leaving a stale, silently-wrong monitor behind -- which is
        # exactly what the hand-copied form did when the 2026-09-07 route
        # move retired the /grafana/ and /git/ prefixes these used to
        # point at. Keyed by a substring unique to the wanted vhost (the
        # FQDN form, not the bare `http://<name>` redirect vhosts -- those
        # keys contain no dot); a label matching nothing is an EVAL ERROR,
        # not an empty row, so removing a service forces a glance edit in
        # the same change. The one hand-written row is golink, which is
        # not this host's vhost at all (own tailnet device, golink.nix).
        monitored = {
            grafana = "Grafana";
            git     = "Forgejo";
        };

        monitoredSite = vhosts: label: title:
            let
                matches = builtins.filter
                    (v: lib.hasInfix label v && lib.hasInfix "." v)
                    vhosts;
            in
                if matches == []
                then builtins.throw "glance monitor: no caddy vhost matches '${label}' -- the service moved or was renamed; update glance.nix's `monitored` in the same change (issue #221)"
                else {
                    inherit title;
                    url = "https://${builtins.head matches}/";
                };
    in {
        flake.modules.nixos.${moduleName} = { config, ... }: {
            # # description = "glance -- the service index for this host: what's running, whether it's up";

            services.glance = {
                enable = true;

                settings.server = {
                    # Also the module's own default, stated anyway: here
                    # "listens on loopback" IS the security model, and the
                    # two neighbours MOVED to loopback (grafana.nix,
                    # forgejo.nix) say so at their listener. Upstream glance
                    # defaults to every interface; nixpkgs narrows it.
                    host = "127.0.0.1";

                    # 3000 grafana, 3001 forgejo, 3002 homepage (this
                    # module's old slot, kept by #291), 3003 opencode,
                    # 3004 here. NOT glance's own default 8080 --
                    # monitoring/cadvisor.nix already holds 8080 on this
                    # host, and two services on one port is a bind failure
                    # at start, not an eval error.
                    port = 3004;

                    # See this file's header: trust Caddy's X-Forwarded-*.
                    proxied = true;
                };

                settings.pages = [
                    {
                        name = "Home";

                        columns = [
                            {
                                size = "full";
                                widgets = [
                                    {
                                        # TWO ROWS READ OK FOR NON-OBVIOUS
                                        # REASONS, both reasoned from
                                        # source, both of which would go
                                        # red with nothing actually broken:
                                        #
                                        #  - Grafana answers with a 302 to
                                        #    its /login, and
                                        #    `statusCodeToText` treats only
                                        #    200 (or an explicit
                                        #    `alt-status-codes` entry) as
                                        #    OK. It reads OK because
                                        #    glance's `defaultHTTPClient`
                                        #    (widget-utils.go) sets no
                                        #    `CheckRedirect`, so Go follows
                                        #    up to 10. A glance that stops
                                        #    following wants
                                        #    `alt-status-codes: [302]`, not
                                        #    a Grafana change.
                                        #  - `http://go/` reads OK, i.e.
                                        #    golink answers a request from
                                        #    cube -- uncertain beforehand,
                                        #    since golink is a SEPARATE
                                        #    tailnet device (tsnet): it
                                        #    needs MagicDNS resolving `go`
                                        #    from cube AND golink serving
                                        #    that node without interactive
                                        #    auth.
                                        #
                                        # Widget content renders behind
                                        # `/api/pages/home/content/`, not
                                        # the initial HTML -- a page 200
                                        # proves almost nothing; that
                                        # endpoint is where to verify.
                                        type  = "monitor";
                                        title = "Services";

                                        # A GET per site per minute: cheap,
                                        # keeps the page honest, hammers
                                        # nothing.
                                        cache = "1m";

                                        # Checked through the PROXY, at the
                                        # URLs a person uses, not
                                        # 127.0.0.1:300x -- tests the whole
                                        # path (MagicDNS, tailnet, caddy
                                        # routing, TLS cert, app), not the
                                        # app alone. A caddy
                                        # misconfiguration should show up
                                        # here; a loopback check would hide
                                        # exactly the bug that actually
                                        # happened (the /git 404).
                                        #
                                        # Derived from caddy's vhost table --
                                        # see `monitored` above for why and
                                        # for the throw-on-orphan guarantee.
                                        sites = (map
                                            (label: monitoredSite
                                                (builtins.attrNames
                                                    config.services.caddy.virtualHosts)
                                                label
                                                monitored.${label})
                                            (builtins.attrNames monitored)) ++ [
                                            {
                                                # Its own tailnet device
                                                # (shortlinks/golink.nix
                                                # embeds tsnet), listed as a
                                                # fleet service -- cube does
                                                # not serve it.
                                                title = "golink";
                                                url   = "http://go/";
                                            }
                                        ];
                                    }
                                ];
                            }

                            {
                                size = "small";
                                widgets = [
                                    {
                                        type = "server-stats";

                                        # `local` reads /proc directly. The
                                        # nixpkgs module sets
                                        # `ProcSubset = "all"` on the unit --
                                        # that is what makes it work under
                                        # the DynamicUser sandbox; without
                                        # it the widget renders empty, not
                                        # an error.
                                        servers = [
                                            {
                                                type = "local";
                                                name = "nire-cube";
                                            }
                                        ];
                                    }

                                    {
                                        # Added 2026-09-09 (issue #226).
                                        # Keyless: glance's weather widget
                                        # fetches from open-meteo.com, no
                                        # API key property exists (checked
                                        # the v0.8.5 docs, matching the
                                        # pinned package -- `nix eval
                                        # .#...services.glance.package`).
                                        # An invalid location is a glance
                                        # STARTUP error, not a broken
                                        # widget, so the city has to
                                        # actually resolve in open-meteo's
                                        # geocoder.
                                        type = "weather";

                                        # The one location fact this repo
                                        # holds: tz.nix's fleet default
                                        # `time.timeZone =
                                        # "America/New_York"`. Change here
                                        # if the dashboard should show
                                        # somewhere else -- nothing else
                                        # in the config pins a city.
                                        location = "New York, United States";

                                        # en_US locale, per locale.nix's
                                        # `i18n.defaultLocale`; glance's
                                        # own default is metric.
                                        units = "imperial";
                                    }

                                    {
                                        # Added 2026-09-09 (issue #207).
                                        # DATE GRID ONLY: glance's calendar
                                        # widget takes no event feed/ICS
                                        # property at all (checked the
                                        # v0.8.5 docs) -- it cannot show
                                        # the household events #230 wants;
                                        # that needs a custom-api/backend
                                        # decision. `first-day-of-week`
                                        # left at glance's default
                                        # (`monday`), which matches nothing
                                        # in particular -- change here if
                                        # it should be sunday.
                                        # Bare date grid -- homepage's
                                        # calendar service widgets are the
                                        # events-capable answer (#289/#290
                                        # were filed to patch THIS; they
                                        # closed superseded when homepage
                                        # landed). Comparison fodder.
                                        type = "calendar";
                                    }
                                ];
                            }

                            {
                                # The four to-do lists of issue #209, in
                                # their own trailing small column. Two
                                # properties worth knowing before
                                # extending (checked against the v0.8.5
                                # docs, matching the pinned package):
                                #
                                #   - Distinct `id`s are what makes this
                                #     four lists rather than one; there is
                                #     no title/label property, so the
                                #     "categories" the issue asks for are
                                #     only distinguishable by position and
                                #     content.
                                #   - Tasks live in each BROWSER's local
                                #     storage -- per-device, not shared,
                                #     and lost if that browser's storage
                                #     is cleared. Right for a personal
                                #     dashboard; wrong for the shared
                                #     household tracking #230 wants, which
                                #     needs a real backend.
                                size = "small";
                                widgets = [
                                    {
                                        type = "to-do";
                                        id   = "1";
                                    }
                                    {
                                        type = "to-do";
                                        id   = "2";
                                    }
                                    {
                                        type = "to-do";
                                        id   = "3";
                                    }
                                    {
                                        type = "to-do";
                                        id   = "4";
                                    }
                                ];
                            }
                        ];
                    }
                ];
            };

            # No firewall entry and no glance-persist.nix, for the reasons
            # the neighbouring modules give: loopback bind, so nothing
            # arrives at the firewall; cube has a plain persistent root
            # (cube-configuration.nix's header), so /var/lib/glance survives
            # reboots. Nothing in /var/lib/glance is worth keeping anyway --
            # widgets derive from live state, config is from the store.
        };
}
