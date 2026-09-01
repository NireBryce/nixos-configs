# Writes this host's tailnet FQDN to /persist/tailnet-fqdn, read from
# `tailscale status --json` on every boot. caddy.nix, grafana.nix,
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
# NOT under /persist/secrets/, DELIBERATELY, though it started there and
# broke everything reading it -- see the WORLD-READABLE section below. This
# value isn't secret (see 2026-09-01's conversation: knowing a tailnet's
# name doesn't grant access to it, Tailscale's isolation is node-key-based,
# not name-secrecy-based) and filing it next to grafana-secret-key invited
# exactly the failure that happened: looking like the same class of file as
# an actual root:600 secret, one directory-listing away from someone (or a
# future session) "fixing" it back to that mode as an apparent regression.
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
# WORLD-READABLE, NOT 600 -- REAL BUG, HIT ON FIRST DEPLOY 2026-09-01: this
# used to write with `umask 077` (owner-only), the grafana-secret-key
# pattern. `nix build`/`nix eval` (`just build`/`just switch`, via `nh`)
# EVALUATE as the invoking user (elly), not root -- only the sandboxed
# derivation BUILD step runs via the nix-daemon as root. A root:600 file is
# unreadable to that evaluation, so `builtins.readFile` in caddy.nix/
# grafana.nix/forgejo.nix/glance.nix hit a permission error on every real
# switch after the first. It didn't surface as a build failure: Nix's flake
# eval cache (~/.cache/nix/eval-cache-v*.sqlite, keyed on the flake's `self`
# rev + attribute path, not on external files read mid-evaluation) had
# already cached the FIRST evaluation's result -- from before this file
# existed at all, when `pathExists` was false and the placeholder was a
# clean success -- and kept serving that stale cached value instead of
# re-running the read and hitting the permission error fresh. Two switches
# in a row produced the byte-identical store path before this was caught,
# both silently wrong (Caddy/Grafana/Forgejo/glance all pointed at the
# `.invalid` placeholder, live). `nix eval --impure --raw --expr
# "builtins.readFile /persist/tailnet-fqdn"` run directly (bypassing the
# flake attribute cache entirely) is what actually surfaced the permission
# error and found this. Confirmed the fix, not assumed: a new commit
# (this comment's own) changes the flake's `self` rev, which busts that
# cache entry on its own -- no separate cache-clearing needed once the
# permission itself is fixed.
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
                description = "Write this host's tailnet FQDN to /persist/tailnet-fqdn from tailscale status";
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
                    out=/persist/tailnet-fqdn

                    for _ in $(seq 1 30); do
                        dns=$(tailscale status --json | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
                        if [ -n "$dns" ]; then
                            # World-readable (022), not 077 -- see the
                            # header's WORLD-READABLE section. Root-owned
                            # (this unit runs as root by default, no User=
                            # set) so only this service can write it.
                            umask 022
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
