# glance: the service index for this host -- what's running, whether it's
# up, how the machine is doing. Added 2026-08-24, cube-only, own category
# (`nire/landing/`) -- the category-as-optionality mechanism CLAUDE.md's
# Architecture section gives `monitoring`, `git-forge`, `shortlinks` and
# `reverse-proxy`.
#
# Named `landing`, NOT `dashboard`, not `glance`. Not `glance` for the
# collision reason `git-forge` isn't `forgejo` (category + module sharing a
# name declare the same `flake.modules.nixos.<name>` and silently MERGE).
# Not `dashboard` because `monitoring` next door is full of Grafana
# dashboards; this is the page you LAND on, Grafana is where you read
# graphs.
#
# NOT a second monitoring system: the `monitor` widget does an HTTP GET and
# reports the status code -- no scraping, storage, alerting, retention.
# prometheus.nix is what knows what CPU was an hour ago; this answers "is
# it up right now, and what's the URL", the question `wiki/homelab/
# README.md` answers for humans.
#
# SITS AT `/`, THE ONE ROUTE WITH NO PREFIX PROBLEM. reverse-proxy/caddy.nix
# mounts Grafana at /grafana and Forgejo at /git with OPPOSITE prefix
# handling (`handle` vs `handle_path`; that file, lessons-learned #41).
# glance is the fallback `handle` at the vhost root: nothing stripped,
# `base-url` unset. Under a prefix, glance's docs require `base-url` set
# AND the proxy stripping -- Forgejo's shape, not Grafana's.
#
# `proxied = true` is not cosmetic: glance then trusts `X-Forwarded-*` and
# sees the real client instead of 127.0.0.1; without it every visitor looks
# like the proxy.
#
# NO ICONS, DELIBERATELY. `si:`/`sh:`/`di:`/`mdi:` icons "are loaded
# externally and are hosted on cdn.jsdelivr.net" (glance's own docs). A
# page whose point is not leaving the tailnet must not pull icons from a
# CDN on every load; if ever wanted, `assets-path` serves a local
# directory under /assets/.
#
# ONLY CLICKABLE SERVICES ARE LISTED: the monitor widget's title IS the
# link, so a loopback-only service (prometheus 127.0.0.1:9090,
# node-exporter, cadvisor, libvirt-exporter) would render as a 404 link --
# fine as a health check, misleading as a UI. Their health is in Grafana,
# which IS listed. Don't add them without a browser-followable URL.
#
# STATUS: runtime-verified on nire-cube, 2026-08-24, first switch, no fixes
# (glance.service active, NRestarts=0, 3002 on 127.0.0.1; from another
# tailnet host https://ts-cube.moose-micro.ts.net/ 200 over validated TLS).
#
# Widget content renders behind `/api/pages/home/content/`, not the initial
# HTML -- a page 200 proves almost nothing; that endpoint is where to look
# (all three sites OK; server-stats rendering CPU/SWAP for `nire-cube`).
#
# Two facts reasoned from source; both would have been quiet wrong-looking
# output, not errors:
#
#   - Grafana answers /grafana/ with a 302 to /grafana/login, and
#     `statusCodeToText` treats ONLY 200 (or an explicit `alt-status-codes`
#     entry) as OK. It reads OK because glance's `defaultHTTPClient`
#     (widget-utils.go) sets no `CheckRedirect`, so Go's
#     follow-up-to-10 default applies. If a future glance stops following
#     redirects, the row goes red with nothing broken -- fix is
#     `alt-status-codes: [302]`, not a Grafana change.
#   - `http://go/` reads OK, i.e. golink answers a request from cube --
#     genuinely uncertain beforehand: golink is a separate tailnet device
#     (tsnet), so this needed MagicDNS resolving `go` from cube AND golink
#     serving that node without interactive auth.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Written out rather than shared, same as reverse-proxy/caddy.nix,
        # monitoring/grafana.nix and git-forge/forgejo.nix: nothing declares
        # options (CLAUDE.md, Architecture) -- four copies, moved together.
        tailnetFqdn = "ts-cube.moose-micro.ts.net";
    in {
        flake.modules.nixos.${moduleName} = {
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

                    # 3000 grafana, 3001 forgejo, 3002 here. NOT glance's own
                    # default 8080 -- monitoring/cadvisor.nix already holds
                    # that port on this host, and two services on one port is
                    # a bind failure at start, not an eval error.
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
