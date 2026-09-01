# Writes this host's tailnet FQDN to /persist/secrets/tailnet-fqdn, read
# from `tailscale status --json` on every boot. caddy.nix, grafana.nix,
# forgejo.nix and glance.nix all read that file (see their own `tailnetFqdn`
# `let` bindings) instead of a literal committed string -- added 2026-09-01
# after the literal `ts-cube.<tailnet>.ts.net` sat in this repo's git
# history (and, before that, in wiki/AGENTS.md prose) for a public
# GitHub repo to read. Filed as its own subdirectory here rather than folded
# into caddy.nix: it isn't caddy-specific (grafana.nix/forgejo.nix/glance.nix
# all depend on it too), but it belongs under `reverse-proxy` rather than
# `system/networking/tailscale.nix` because only hosts importing this
# category need it at all -- same "state that only matters to one thing
# lives next to what needs it" reasoning tailscale-persist.nix gives for its
# own filing, applied to the consumer side instead of the generator side.
#
# EVAL-TIME CONSUMERS, RUNTIME PRODUCER -- the four files above read this
# file with `builtins.readFile` at Nix EVAL time, baked into the store at
# build time. This service only keeps the FILE current, on every boot; it
# does NOT make an already-built config update itself. A tailnet rename:
# this service picks up the new FQDN on the next boot (or a manual restart),
# but the change only reaches Caddy/Grafana/Forgejo/glance after `just
# switch` on cube re-evaluates and reads the file again. Deliberate,
# matching how every other config change in this repo already works --
# nothing here self-applies without a switch.
#
# Retries for up to a minute: tailscaled needs to have synced with the
# coordination server before `.Self.DNSName` is populated, and this unit's
# own `after`/`wants` on tailscaled.service only guarantees the daemon has
# STARTED, not that it has finished that handshake yet -- the same ordering
# gap caddy.nix's own `after = [ "tailscaled.service" ]` comment already
# notes for cert issuance.
#
# Atomic write (temp file + rename) so a reader never sees a truncated file
# if this races a config read -- unlikely given systemd-services vs Nix-eval
# timing, but cheap to make impossible rather than reason about.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            systemd.services.${moduleName} = {
                description = "Write this host's tailnet FQDN to /persist/secrets/tailnet-fqdn from tailscale status";
                after       = [ "tailscaled.service" ];
                wants       = [ "tailscaled.service" ];
                wantedBy    = [ "multi-user.target" ];

                serviceConfig = {
                    Type            = "oneshot";
                    RemainAfterExit = true;
                };

                path = [ pkgs.tailscale pkgs.jq ];

                script = ''
                    set -euo pipefail
                    out=/persist/secrets/tailnet-fqdn
                    mkdir -p "$(dirname "$out")"

                    for _ in $(seq 1 30); do
                        dns=$(tailscale status --json | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
                        if [ -n "$dns" ]; then
                            umask 077
                            printf '%s\n' "$dns" > "$out.new"
                            mv "$out.new" "$out"
                            exit 0
                        fi
                        sleep 2
                    done

                    echo "tailnet-fqdn-refresh: tailscale never reported a DNSName after 60s" >&2
                    exit 1
                '';
            };
        };
}
