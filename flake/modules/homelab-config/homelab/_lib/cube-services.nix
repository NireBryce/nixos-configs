# The web services on nire-cube that get their own Tailscale Service name,
# written in one place. A plain attrset `import`ed by path, filed under `_lib/`
# because import-tree ignores any path containing `/_`.
#
# Each of these facts used to be spelled out in the app's own module AND in
# caddy.nix (and the names again in serve.nix), with a comment on each copy
# saying so: nothing declares options across these modules, so a port or
# name changed in one place was a mismatch found at runtime -- Caddy
# proxying to a port the app no longer listens on, or an app whose
# `root_url` names a vhost Caddy does not serve. Now:
#   - the app modules (grafana.nix, forgejo.nix) read `port` / `url` / `fqdn`
#   - caddy.nix's `mkTsService` builds each service's vhosts from its entry
#   - serve.nix forwards TCP for every entry
# so ADDING a service is one entry here plus its guard in caddy.nix (a
# missing guard fails evaluation) -- reverse-proxy's README and
# wiki/homelab/reaching-services.md have the control-plane half.
#
# `ts-cube`, NOT `nire-cube`: this tailnet renames devices fleet-wide
# (tailscale.nix's trap #1), verified live 2026-08-24. Renaming an entry
# here does NOT rename the control-plane `svc:` object.
let
    tailnet = "moose-micro.ts.net";
    device  = "ts-cube";

    mk = name: { port }: {
        inherit name port;
        fqdn = "${name}.${tailnet}";
        url  = "https://${name}.${tailnet}/";
    };
in {
    inherit tailnet device;

    # The device's own MagicDNS name, e.g. what the bare host answers 404 on.
    deviceFqdn = "${device}.${tailnet}";

    # `port` is the app's loopback listen port (Caddy reverse_proxies to it).
    # Forgejo is 3001 because grafana already holds 3000.
    services = builtins.mapAttrs mk {
        grafana.port = 3000;
        git.port     = 3001;    };
}
