# services.tailscale.serve: Grafana and Forgejo get their own Tailscale
# Services names (svc:grafana, svc:git) instead of a Caddy path prefix
# under ts-cube.moose-micro.ts.net. See this directory's README for how
# svc:grafana/svc:git came to exist on the tailnet (they're a SEPARATE API
# resource from the ACL, created via `vip-put`, not declared here or in
# the policy file), and tailscale.nix's "FOUR REAL TRAPS" for the tagging
# incident hit getting nire-cube onto tag:homelab-cube in the first place.
#
# UPSTREAM MODULE, NOT HAND-ROLLED: nixos/modules/services/networking/
# tailscale-serve.nix (pinned nixpkgs, confirmed present at this pin --
# newer than when caddy.nix's Tailscale-cert mechanism was last checked
# against source). It renders `services` below to a JSON file
# (svc:-prefixed automatically, do not add the prefix yourselves) and runs
# `tailscale serve set-config --all <file>` as a oneshot ordered after
# tailscaled -- declarative and git-tracked, unlike the ACL/vip-services
# state this pairs with.
#
# `tcp:443` on the PUBLIC side always gets TLS from tailscaled (same
# `.ts.net`-domain cert mechanism caddy.nix documents in depth) regardless
# of the backend scheme -- the endpoint value's `http://` here describes
# the LOOPBACK leg only, matching the classic `tailscale serve --https=443
# http://localhost:PORT` invocation. Backends are plain HTTP on loopback,
# same as caddy.nix's targets; nothing about grafana.nix/forgejo.nix's own
# listener config changes.
#
# WHAT THIS REPLACES: caddy.nix's `@grafana`/`handle_path /git/*` routes,
# and the serve_from_sub_path/ROOT_URL path-prefix settings in
# grafana.nix/forgejo.nix that existed ONLY because MagicDNS gives one
# name per device (reverse-proxy.md's "Paths, not subdomains, and that's
# forced" -- now false for these two, since each has its own name).
# glance (nire/landing/) still serves at the bare `ts-cube.moose-micro.
# ts.net` root through caddy.nix, untouched -- it never had a
# subpath question.
#
# NOT YET RUNTIME-VERIFIED. caddy.nix's own history needed TWO switches to
# get the two apps' opposite prefix-handling right the first time
# (wiki/lessons-learned.md #41); this is the same class of change,
# inverted, and deserves the same real checklist
# reverse-proxy-history.md used: TLS handshake against each service name
# specifically (not just the bare hostname), Forgejo's generated clone
# URLs, Grafana's dashboard links, confirming the old `/grafana/`/`/git/`
# paths are actually gone rather than assumed gone.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.tailscale.serve = {
                enable = true;

                services = {
                    # Key becomes svc:grafana/svc:git -- the module adds
                    # the prefix, see its own option doc (tailscale-serve
                    # .nix in pinned nixpkgs).
                    grafana.endpoints."tcp:443" = "http://127.0.0.1:3000";
                    git.endpoints."tcp:443"     = "http://127.0.0.1:3001";
                };
            };
        };
}
