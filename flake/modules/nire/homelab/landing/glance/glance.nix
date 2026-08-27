# glance: the service index for this host -- what's running, whether it's up,
# and how the machine itself is doing. Added 2026-08-24, cube-only, own
# category (`nire/landing/`) for the same "if something shared needs to be
# optional, a category is the mechanism" reason `monitoring`, `git-forge`,
# `shortlinks` and `reverse-proxy` each already give (CLAUDE.md's
# Architecture section).
#
# The category is `landing`, NOT `dashboard`, and not `glance` either. Not
# `glance` for the collision reason `git-forge` isn't `forgejo` (a category
# and its one module sharing a name declare the same
# `flake.modules.nixos.<name>` attribute and silently MERGE). Not `dashboard`
# because `monitoring` next door is full of Grafana dashboards, and two
# categories both reasonably called "the dashboard one" is the kind of
# ambiguity that costs a grep later. This is the page you LAND on; Grafana is
# where you go to read graphs.
#
# WHAT IT IS NOT: a second monitoring system. The `monitor` widget below does
# an HTTP GET and reports the status code -- it does not scrape, store, alert,
# or retain anything. prometheus.nix is still what knows what CPU usage was an
# hour ago. This answers "is it up right now, and what's the URL", which is
# the question `wiki/homelab/README.md` exists to answer for humans and which
# nothing on the machine answered before.
#
# IT SITS AT `/`, WHICH MAKES IT THE ONE ROUTE WITH NO PREFIX PROBLEM.
# reverse-proxy/caddy.nix mounts Grafana at /grafana and Forgejo at /git, and
# those two need OPPOSITE prefix handling (`handle` vs `handle_path`, see that
# file and lessons-learned #41). glance is the fallback `handle` at the root
# of the same vhost, so nothing is stripped, nothing is preserved, and
# `base-url` stays unset. If it ever moves under a prefix, glance's own docs
# are explicit that `base-url` must be set AND the proxy must strip -- i.e.
# Forgejo's shape, not Grafana's.
#
# `proxied = true` is not cosmetic: it tells glance to trust `X-Forwarded-*`,
# which is what makes it see the real client rather than 127.0.0.1 for every
# request. Caddy sets those headers itself; without this every visitor looks
# like the proxy.
#
# NO ICONS, DELIBERATELY. The monitor and bookmarks widgets take an `icon`
# with `si:`/`sh:`/`di:`/`mdi:` prefixes -- and glance's own documentation
# says those "are loaded externally and are hosted on cdn.jsdelivr.net". This
# is a page reachable only from the tailnet, whose entire point is that it
# doesn't leave the tailnet; pulling an icon per service from a CDN on every
# load would quietly undo that for no gain over three legible titles. If icons
# are ever wanted, `assets-path` serves a local directory under /assets/ and
# is the way to do it without the CDN.
#
# ONLY CLICKABLE SERVICES ARE LISTED. The monitor widget's title IS the link,
# so a loopback-only service (prometheus on 127.0.0.1:9090, node-exporter,
# cadvisor, libvirt-exporter) would render as a link that 404s in the reader's
# browser -- correct as a health check, actively misleading as a UI. Their
# health shows up in Grafana, which IS listed. Don't add them here without
# also giving them a URL a browser on another host can actually follow.
#
# STATUS: RUNTIME-VERIFIED on nire-cube, 2026-08-24, first switch, no fixes
# needed. `glance.service` `active (running)` at `NRestarts=0`, 0 failed
# units, 3002 bound to 127.0.0.1 only, and from ANOTHER tailnet host
# `https://ts-cube.moose-micro.ts.net/` returns 200 over validated TLS with
# `<title>Home</title>`.
#
# The widget content is rendered behind `/api/pages/home/content/` rather
# than in the initial HTML, so checking the page returns 200 proves almost
# nothing about the widgets -- that endpoint is where to look. It reported
# all three sites OK (65ms/62ms/68ms) and the server-stats widget rendering
# CPU/SWAP for `nire-cube`.
#
# Two things that were reasoned from source before the switch and are now
# facts, both of which would have been quiet wrong-looking output rather
# than errors:
#
#   - Grafana answers /grafana/ with a 302 to /grafana/login, and
#     `statusCodeToText` treats ONLY 200 (or an explicit `alt-status-codes`
#     entry) as OK. It reads OK because glance's `defaultHTTPClient`
#     (widget-utils.go) sets no `CheckRedirect`, so Go's default
#     follow-up-to-10 policy applies. If a future glance ever stops
#     following redirects, this row goes red with nothing actually broken --
#     `alt-status-codes: [302]` would be the fix, not a change to Grafana.
#   - `http://go/` reads OK too, i.e. golink answers a request originating
#     from cube. That was genuinely uncertain: it's a separate tailnet
#     device (tsnet), so this depended on MagicDNS resolving `go` from cube
#     AND golink serving its index to that node without interactive auth.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Written out rather than shared, same as reverse-proxy/caddy.nix,
        # monitoring/grafana.nix and git-forge/forgejo.nix: nothing in this
        # tree declares options (CLAUDE.md, Architecture), so this string
        # lives in four files now and they move together.
        tailnetFqdn = "ts-cube.moose-micro.ts.net";
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "glance -- the service index for this host: what's running, whether it's up";

            services.glance = {
                enable = true;

                settings.server = {
                    # Also the module's own default, stated anyway: on this
                    # host "listens on loopback" is the security model rather
                    # than an implementation detail, and the two neighbours
                    # that had to be MOVED to loopback (grafana.nix,
                    # forgejo.nix) both say so at their own listener. Upstream
                    # glance's default is every interface; nixpkgs narrows it.
                    host = "127.0.0.1";

                    # 3000 grafana, 3001 forgejo, 3002 here. NOT glance's own
                    # default of 8080 -- monitoring/cadvisor.nix already holds
                    # that port on this host, and two services defaulting to
                    # the same port is a bind failure at start, not an eval
                    # error.
                    port = 3002;

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
                                        type  = "monitor";
                                        title = "Services";

                                        # A GET per site per minute, which is
                                        # cheap and keeps the page honest
                                        # without hammering anything.
                                        cache = "1m";

                                        # Checked through the PROXY, at the
                                        # same URLs a person would use, not at
                                        # 127.0.0.1:300x. That makes this a
                                        # test of the whole path -- MagicDNS,
                                        # the tailnet, caddy's routing, the
                                        # TLS cert, and the app -- rather than
                                        # of the app alone. A caddy
                                        # misconfiguration should show up
                                        # here; a loopback check would hide
                                        # exactly the class of bug that
                                        # actually happened (the /git 404).
                                        sites = [
                                            {
                                                title = "Grafana";
                                                url   = "https://${tailnetFqdn}/grafana/";
                                            }
                                            {
                                                title = "Forgejo";
                                                url   = "https://${tailnetFqdn}/git/";
                                            }
                                            {
                                                # Its own tailnet device, not
                                                # a path on this host --
                                                # shortlinks/golink.nix embeds
                                                # tsnet. Listed here because
                                                # it's a service on this
                                                # fleet, not because cube
                                                # serves it.
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
                                        # nixpkgs module already sets
                                        # `ProcSubset = "all"` on the unit,
                                        # which is what makes that work under
                                        # its DynamicUser sandbox -- without
                                        # it this widget renders empty rather
                                        # than failing loudly.
                                        servers = [
                                            {
                                                type = "local";
                                                name = "nire-cube";
                                            }
                                        ];
                                    }
                                ];
                            }
                        ];
                    }
                ];
            };

            # No firewall entry and no glance-persist.nix, for the reasons the
            # neighbouring modules each give: this binds loopback so nothing
            # arrives at the firewall for it, and cube has a plain persistent
            # root (cube-configuration.nix's header) so /var/lib/glance
            # survives reboots on its own. Note there is nothing in
            # /var/lib/glance worth keeping anyway -- every widget here is
            # derived from live state, and the config itself comes from the
            # store.
        };
}
